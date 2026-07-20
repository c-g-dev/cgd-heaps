package cgd.debug;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.util.Highlighter;
import h2d.Object;
import h2d.Text;
import h2d.col.Point;
import h3d.mat.Texture;
import haxe.Json;
import haxe.crypto.Base64;
import hscript.Interp;
import hscript.Parser;
import hxd.App;
import hxd.Event;
import hxd.Key;
import hxd.Window;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Lock;
import sys.thread.Thread;

/**
	Unified debug protocol for Heaps apps.

	Owns the agent line-protocol transport (MCP) and can optionally host the
	HTTP Debug Dashboard. Both surfaces share the same app handle and core ops
	(scene dump, screenshot, hscript, highlight, input, props).
**/
class HeapsProtocolServer {
	static var instance: HeapsProtocolServer;

	static inline var MAIN_TIMEOUT_SEC: Float = 10.0;

	var app: App;
	var agentPort: Int;
	var hostDashboard: Bool;
	var dashboardPort: Int;
	var dashboardHost: String;

	var agentSocket: Socket;
	var agentThread: Thread;

	public static function attach(app: App, ?opts: {
		?agentPort: Int,
		?hostDashboard: Bool,
		?dashboardPort: Int,
		?dashboardHost: String
	}): HeapsProtocolServer {
		if (instance != null)
			return instance;
		instance = new HeapsProtocolServer(app, opts);
		instance.start();
		return instance;
	}

	public static inline function getInstance(): HeapsProtocolServer {
		return instance;
	}

	public static inline function getApp(): App {
		return instance != null ? instance.app : null;
	}

	function new(app: App, ?opts: {
		?agentPort: Int,
		?hostDashboard: Bool,
		?dashboardPort: Int,
		?dashboardHost: String
	}) {
		this.app = app;
		this.agentPort = opts != null && opts.agentPort != null ? opts.agentPort : 8080;
		this.hostDashboard = opts != null && opts.hostDashboard != null ? opts.hostDashboard : false;
		this.dashboardPort = opts != null && opts.dashboardPort != null ? opts.dashboardPort : 8083;
		this.dashboardHost = opts != null && opts.dashboardHost != null ? opts.dashboardHost : "127.0.0.1";
	}

	function start(): Void {
		if (hostDashboard) {
			HeapsDebugServer.attach(app, dashboardPort, dashboardHost);
		}
		startAgentTransport();
	}

	function startAgentTransport(): Void {
		agentSocket = new Socket();
		agentSocket.bind(new Host("127.0.0.1"), agentPort);
		agentSocket.listen(1);
		agentThread = Thread.create(runAgentAcceptLoop);
	}

	function runAgentAcceptLoop(): Void {
		while (true) {
			var client = agentSocket.accept();
			if (client == null)
				continue;

			client.setBlocking(true);
			var request = client.input.readLine();
			var response = handleAgentCommand(request);
			client.output.writeString(response);
			client.close();
		}
	}

	/**
		Handle one line-protocol command (used by MCP / AgentServer clients).
	**/
	public function handleAgentCommand(request: String): String {
		if (request == "GET_SCENE" || request == "GET_SCENE_SNAPSHOT") {
			return Json.stringify(runOnMainSync(function() {
				return dumpSceneSnapshot(app.s2d);
			}));
		}
		if (request == "GET_SCREENSHOT") {
			return runOnMainSync(function() {
				return captureScreenshotBase64();
			});
		}
		if (request == "CLEAR_HIGHLIGHT") {
			return Json.stringify(runOnMainSync(function() {
				Highlighter.clear();
				return { success: true };
			}));
		}
		if (StringTools.startsWith(request, "EXECUTE_HSCRIPT:")) {
			var codeBase64 = request.substr("EXECUTE_HSCRIPT:".length);
			var code = Base64.decode(codeBase64).toString();
			return Json.stringify(runOnMainSync(function() {
				return executeHScript(code);
			}));
		}
		if (StringTools.startsWith(request, "HIGHLIGHT_OBJECT:")) {
			var id = request.substr("HIGHLIGHT_OBJECT:".length);
			return Json.stringify(runOnMainSync(function() {
				return highlightObject(id);
			}));
		}
		if (StringTools.startsWith(request, "GET_OBJECT_SCREENSHOT:")) {
			var rest = request.substr("GET_OBJECT_SCREENSHOT:".length);
			var parts = rest.split(":");
			var id = parts[0];
			var padding = parts.length > 1 ? Std.parseInt(parts[1]) : 0;
			if (padding == null)
				padding = 0;
			return Json.stringify(runOnMainSync(function() {
				return captureObjectScreenshotBase64(id, padding);
			}));
		}
		if (StringTools.startsWith(request, "GET_OBJECT_PROPS:")) {
			var id = request.substr("GET_OBJECT_PROPS:".length);
			return Json.stringify(runOnMainSync(function() {
				return getObjectProps(id);
			}));
		}
		if (StringTools.startsWith(request, "SET_OBJECT_PROPS:")) {
			var payload = Base64.decode(request.substr("SET_OBJECT_PROPS:".length)).toString();
			var args: Dynamic = Json.parse(payload);
			return Json.stringify(runOnMainSync(function() {
				return setObjectProps(args.id, args.props);
			}));
		}
		if (StringTools.startsWith(request, "FIND_NODES:")) {
			var payload = Base64.decode(request.substr("FIND_NODES:".length)).toString();
			var filters: Dynamic = Json.parse(payload);
			return Json.stringify(runOnMainSync(function() {
				return findNodes(filters);
			}));
		}
		if (StringTools.startsWith(request, "SEND_INPUT:")) {
			var payload = Base64.decode(request.substr("SEND_INPUT:".length)).toString();
			var input: Dynamic = Json.parse(payload);
			return Json.stringify(runOnMainSync(function() {
				return sendInput(input);
			}));
		}
		return Json.stringify({ success: false, error: "Unknown command" });
	}

	/**
		Synchronous hscript eval on the caller thread (must be main thread).
		Returns `{ success, result, error }` — never throws (debug sandbox).
	**/
	public function executeHScript(code: String): Dynamic {
		var parser = new Parser();
		parser.allowTypes = true;
		parser.allowJSON = true;
		var ast = parser.parseString(code);
		var interp = createInterp();
		var res = interp.execute(ast);
		return { success: true, result: Std.string(res), error: null };
	}

	/**
		Build a shared hscript interpreter with app/scene bindings (and get2d).
	**/
	public function createInterp(): Interp {
		var interp = new Interp();
		interp.variables.set("app", app);
		interp.variables.set("s2d", app.s2d);
		interp.variables.set("s3d", app.s3d);
		interp.variables.set("scene2d", app.s2d);
		interp.variables.set("scene3d", app.s3d);
		interp.variables.set("Std", Std);
		interp.variables.set("Type", Type);
		interp.variables.set("get2d", function(id: String) {
			return resolveObject(id);
		});
		return interp;
	}

	public function resolveObject(id: String): Object {
		if (id == null || id == "")
			return null;
		var byUuid = Object.getObjectByUUID(id);
		if (byUuid != null)
			return byUuid;
		if (HeapsDebugServer.getApp() != null) {
			var reg = HeapsDebugServer.getLastScene2DRegistry();
			if (reg != null) {
				var fromReg = reg.idToObject.get(id);
				if (fromReg != null)
					return fromReg;
			}
		}
		ensureUuids(app.s2d);
		return Object.getObjectByUUID(id);
	}

	function ensureUuids(obj: Object): Void {
		var _ = obj.uuid;
		for (i in 0...obj.numChildren)
			ensureUuids(obj.getChildAt(i));
	}

	/** Unified scene tree: id, type, name, text, bounds, transform. */
	public function dumpSceneSnapshot(obj: Object): Dynamic {
		var bounds = obj.getBounds();
		var data: Dynamic = {
			id: obj.uuid,
			type: Type.getClassName(Type.getClass(obj)),
			name: obj.name,
			x: obj.x,
			y: obj.y,
			scaleX: obj.scaleX,
			scaleY: obj.scaleY,
			rotation: obj.rotation,
			alpha: obj.alpha,
			visible: obj.visible,
			bounds: { x: bounds.xMin, y: bounds.yMin, w: bounds.width, h: bounds.height },
			children: []
		};

		if (Std.isOfType(obj, Text)) {
			data.text = cast(obj, Text).text;
		}

		for (i in 0...obj.numChildren) {
			data.children.push(dumpSceneSnapshot(obj.getChildAt(i)));
		}
		return data;
	}

	/** @deprecated Prefer dumpSceneSnapshot — kept as alias for older callers. */
	public function dumpSceneNode(obj: Object): Dynamic {
		return dumpSceneSnapshot(obj);
	}

	public function captureScreenshotBase64(): String {
		var tex = new Texture(app.s2d.width, app.s2d.height, [Target]);
		app.s2d.drawTo(tex);
		var bytes = tex.capturePixels().toPNG();
		return Base64.encode(bytes);
	}

	public function captureObjectScreenshotBase64(id: String, padding: Int = 0): Dynamic {
		var obj = resolveObject(id);
		if (obj == null)
			return { success: false, error: "Object not found: " + id };

		var tex = new Texture(app.s2d.width, app.s2d.height, [Target]);
		app.s2d.drawTo(tex);
		var pixels = tex.capturePixels();

		var bounds = obj.getBounds();
		var x0 = Math.floor(bounds.xMin) - padding;
		var y0 = Math.floor(bounds.yMin) - padding;
		var x1 = Math.ceil(bounds.xMax) + padding;
		var y1 = Math.ceil(bounds.yMax) + padding;
		if (x0 < 0)
			x0 = 0;
		if (y0 < 0)
			y0 = 0;
		if (x1 > pixels.width)
			x1 = pixels.width;
		if (y1 > pixels.height)
			y1 = pixels.height;
		var w = x1 - x0;
		var h = y1 - y0;
		if (w <= 0 || h <= 0)
			return { success: false, error: "Empty crop bounds for " + id };

		var cropped = pixels.sub(x0, y0, w, h);
		return {
			success: true,
			data: Base64.encode(cropped.toPNG()),
			bounds: { x: x0, y: y0, w: w, h: h }
		};
	}

	public function highlightObject(id: String): Dynamic {
		var obj = resolveObject(id);
		if (obj == null)
			return { success: false, error: "Object not found: " + id };
		Highlighter.highlight(obj);
		return { success: true, id: id };
	}

	public function getObjectProps(id: String): Dynamic {
		var obj = resolveObject(id);
		if (obj == null)
			return { success: false, error: "Object not found: " + id };
		var bounds = obj.getBounds();
		var props: Dynamic = {
			id: obj.uuid,
			type: Type.getClassName(Type.getClass(obj)),
			name: obj.name,
			x: obj.x,
			y: obj.y,
			scaleX: obj.scaleX,
			scaleY: obj.scaleY,
			rotation: obj.rotation,
			alpha: obj.alpha,
			visible: obj.visible,
			bounds: { x: bounds.xMin, y: bounds.yMin, w: bounds.width, h: bounds.height }
		};
		if (Std.isOfType(obj, Text))
			props.text = cast(obj, Text).text;
		return { success: true, props: props };
	}

	public function setObjectProps(id: String, props: Dynamic): Dynamic {
		var obj = resolveObject(id);
		if (obj == null)
			return { success: false, error: "Object not found: " + id };
		if (props == null)
			return { success: false, error: "Missing props" };

		if (Reflect.hasField(props, "x"))
			obj.x = props.x;
		if (Reflect.hasField(props, "y"))
			obj.y = props.y;
		if (Reflect.hasField(props, "scaleX"))
			obj.scaleX = props.scaleX;
		if (Reflect.hasField(props, "scaleY"))
			obj.scaleY = props.scaleY;
		if (Reflect.hasField(props, "scale")) {
			obj.scaleX = props.scale;
			obj.scaleY = props.scale;
		}
		if (Reflect.hasField(props, "rotation"))
			obj.rotation = props.rotation;
		if (Reflect.hasField(props, "alpha"))
			obj.alpha = props.alpha;
		if (Reflect.hasField(props, "visible"))
			obj.visible = props.visible;
		if (Reflect.hasField(props, "name"))
			obj.name = props.name;
		if (Reflect.hasField(props, "text") && Std.isOfType(obj, Text))
			cast(obj, Text).text = props.text;

		return getObjectProps(id);
	}

	public function findNodes(filters: Dynamic): Dynamic {
		if (filters == null)
			filters = {};
		var limit = Reflect.hasField(filters, "limit") ? Std.int(filters.limit) : 50;
		if (limit <= 0)
			limit = 50;
		var matches: Array<Dynamic> = [];
		var path: Array<String> = [];

		function matchesFilters(obj: Object, text: String): Bool {
			if (Reflect.hasField(filters, "visibleOnly") && filters.visibleOnly == true && !obj.visible)
				return false;
			if (Reflect.hasField(filters, "nameEquals") && filters.nameEquals != null) {
				if (obj.name != filters.nameEquals)
					return false;
			}
			if (Reflect.hasField(filters, "nameContains") && filters.nameContains != null) {
				var n = obj.name != null ? obj.name : "";
				if (n.indexOf(filters.nameContains) < 0)
					return false;
			}
			var typeName = Type.getClassName(Type.getClass(obj));
			if (Reflect.hasField(filters, "typeEquals") && filters.typeEquals != null) {
				if (typeName != filters.typeEquals)
					return false;
			}
			if (Reflect.hasField(filters, "typeEndsWith") && filters.typeEndsWith != null) {
				if (!StringTools.endsWith(typeName, filters.typeEndsWith))
					return false;
			}
			if (Reflect.hasField(filters, "textEquals") && filters.textEquals != null) {
				if (text != filters.textEquals)
					return false;
			}
			if (Reflect.hasField(filters, "textContains") && filters.textContains != null) {
				if (text == null || text.indexOf(filters.textContains) < 0)
					return false;
			}
			return true;
		}

		function visit(obj: Object): Void {
			if (matches.length >= limit)
				return;
			var label = obj.name != null ? obj.name : Type.getClassName(Type.getClass(obj));
			path.push(label);
			var text: String = null;
			if (Std.isOfType(obj, Text))
				text = cast(obj, Text).text;
			if (matchesFilters(obj, text)) {
				var bounds = obj.getBounds();
				matches.push({
					id: obj.uuid,
					type: Type.getClassName(Type.getClass(obj)),
					name: obj.name,
					text: text,
					path: path.join("/"),
					bounds: { x: bounds.xMin, y: bounds.yMin, w: bounds.width, h: bounds.height },
					visible: obj.visible
				});
			}
			for (i in 0...obj.numChildren)
				visit(obj.getChildAt(i));
			path.pop();
		}

		visit(app.s2d);
		return { success: true, count: matches.length, nodes: matches };
	}

	public function sendInput(input: Dynamic): Dynamic {
		if (input == null)
			return { success: false, error: "Missing input" };

		var type: String = input.type != null ? Std.string(input.type) : "";
		var win = Window.getInstance();

		if (type == "keyDown" || type == "keyUp" || type == "keyPress") {
			var code = resolveKeyCode(input.key != null ? input.key : input.keyCode);
			if (code < 0)
				return { success: false, error: "Unknown key: " + Std.string(input.key != null ? input.key : input.keyCode) };
			if (type == "keyPress") {
				var down = new Event(EKeyDown);
				down.keyCode = code;
				win.event(down);
				var up = new Event(EKeyUp);
				up.keyCode = code;
				win.event(up);
			} else {
				var e = new Event(type == "keyDown" ? EKeyDown : EKeyUp);
				e.keyCode = code;
				win.event(e);
			}
			return { success: true, type: type, keyCode: code };
		}

		if (type == "mouseMove" || type == "mouseDown" || type == "mouseUp" || type == "click") {
			var x: Float = input.x != null ? input.x : 0;
			var y: Float = input.y != null ? input.y : 0;
			if (input.objectId != null) {
				var obj = resolveObject(Std.string(input.objectId));
				if (obj == null)
					return { success: false, error: "Object not found: " + input.objectId };
				var pt = obj.localToGlobal(new Point(x, y));
				x = pt.x;
				y = pt.y;
			}
			var button = input.button != null ? Std.int(input.button) : 0;
			if (type == "mouseMove") {
				win.event(new Event(EMove, x, y));
			} else if (type == "mouseDown") {
				var e = new Event(EPush, x, y);
				e.button = button;
				win.event(e);
			} else if (type == "mouseUp") {
				var e = new Event(ERelease, x, y);
				e.button = button;
				win.event(e);
			} else {
				var down = new Event(EPush, x, y);
				down.button = button;
				win.event(down);
				var up = new Event(ERelease, x, y);
				up.button = button;
				win.event(up);
			}
			return { success: true, type: type, x: x, y: y };
		}

		return { success: false, error: "Unknown input type: " + type };
	}

	function resolveKeyCode(key: Dynamic): Int {
		if (key == null)
			return -1;
		switch (Type.typeof(key)) {
			case TInt, TFloat:
				return Std.int(key);
			default:
		}
		var name = StringTools.trim(Std.string(key)).toUpperCase();
		name = StringTools.replace(name, " ", "_");
		name = StringTools.replace(name, "-", "_");
		return switch (name) {
			case "BACKSPACE": Key.BACKSPACE;
			case "TAB": Key.TAB;
			case "ENTER", "RETURN": Key.ENTER;
			case "SHIFT": Key.SHIFT;
			case "CTRL", "CONTROL": Key.CTRL;
			case "ALT": Key.ALT;
			case "ESCAPE", "ESC": Key.ESCAPE;
			case "SPACE", "SPACEBAR": Key.SPACE;
			case "PAGEUP", "PGUP": Key.PGUP;
			case "PAGEDOWN", "PGDOWN": Key.PGDOWN;
			case "END": Key.END;
			case "HOME": Key.HOME;
			case "LEFT": Key.LEFT;
			case "UP": Key.UP;
			case "RIGHT": Key.RIGHT;
			case "DOWN": Key.DOWN;
			case "INSERT": Key.INSERT;
			case "DELETE", "DEL": Key.DELETE;
			case "A": Key.A;
			case "B": Key.B;
			case "C": Key.C;
			case "D": Key.D;
			case "E": Key.E;
			case "F": Key.F;
			case "G": Key.G;
			case "H": Key.H;
			case "I": Key.I;
			case "J": Key.J;
			case "K": Key.K;
			case "L": Key.L;
			case "M": Key.M;
			case "N": Key.N;
			case "O": Key.O;
			case "P": Key.P;
			case "Q": Key.Q;
			case "R": Key.R;
			case "S": Key.S;
			case "T": Key.T;
			case "U": Key.U;
			case "V": Key.V;
			case "W": Key.W;
			case "X": Key.X;
			case "Y": Key.Y;
			case "Z": Key.Z;
			default: -1;
		};
	}

	/**
		Run `fn` on the Heaps main thread and wait. Always releases the lock so a
		throwing callback cannot permanently hang the agent accept loop.
	**/
	public function runOnMainSync(fn: Void->Dynamic): Dynamic {
		var result: Dynamic = null;
		var lock = new Lock();
		haxe.MainLoop.runInMainThread(function() {
			result = safeCall(fn);
			lock.release();
		});
		if (!lock.wait(MAIN_TIMEOUT_SEC)) {
			return { success: false, error: "Timed out waiting for main thread (" + MAIN_TIMEOUT_SEC + "s)" };
		}
		return result;
	}

	/**
		Debug-sandbox wrapper: convert unexpected throws into structured results so
		agent/MCP callers always get a response (and the accept-loop lock is released).
	**/
	public static function safeCall(fn: Void->Dynamic): Dynamic {
		try {
			return fn();
		} catch (e:Dynamic) {
			return { success: false, result: null, error: Std.string(e) };
		}
	}
}
