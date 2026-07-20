package cgd.cli.mcp;

import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;

class McpMain {
	public static function run(callerCwd: String, libraryRoot: String, ?customStdin: haxe.io.Input, ?customStdout: haxe.io.Output): Void {
		var stdin = customStdin != null ? customStdin : Sys.stdin();
		var stdout = customStdout != null ? customStdout : Sys.stdout();

		while (true) {
			var line = stdin.readLine();
			var req: Dynamic = Json.parse(line);

			if (req.method == "initialize") {
				sendResponse(stdout, req.id, {
					protocolVersion: "2024-11-05",
					capabilities: {},
					serverInfo: { name: "cgdheaps-mcp", version: "1.0.0" }
				});
			} else if (req.method == "tools/list") {
				sendResponse(stdout, req.id, { tools: toolDefs() });
			} else if (req.method == "tools/call") {
				handleToolCall(stdout, req);
			} else if (req.method == "notifications/initialized") {
				// no-op
			}
		}
	}

	static function toolDefs(): Array<Dynamic> {
		return [
			{
				name: "get_scene_tree",
				description: "Gets the Heaps 2D scene graph (JSON) with id/uuid, type, name, text, bounds, and transform fields.",
				inputSchema: { type: "object", properties: {} }
			},
			{
				name: "get_scene_snapshot",
				description: "Alias of get_scene_tree: unified snapshot with UUIDs, text, bounds, and transforms.",
				inputSchema: { type: "object", properties: {} }
			},
			{
				name: "get_screenshot",
				description: "Captures the current full screen of the game as a PNG.",
				inputSchema: { type: "object", properties: {} }
			},
			{
				name: "get_object_screenshot",
				description: "Captures a PNG cropped to an object's bounds (optional padding).",
				inputSchema: {
					type: "object",
					properties: {
						id: { type: "string", description: "Object UUID" },
						paddingPx: { type: "number", description: "Padding around bounds in pixels" }
					},
					required: ["id"]
				}
			},
			{
				name: "execute_hscript",
				description: "Executes hscript on the Heaps main thread. Bindings: app, s2d, s3d, scene2d, scene3d, Std, Type, get2d(id). Returns {success,result,error}.",
				inputSchema: {
					type: "object",
					properties: {
						code: { type: "string", description: "The hscript code to execute" }
					},
					required: ["code"]
				}
			},
			{
				name: "highlight_object",
				description: "Draws the cyan/green highlight overlay on the given object UUID (same as dashboard /highlightobject).",
				inputSchema: {
					type: "object",
					properties: {
						id: { type: "string", description: "Object UUID" }
					},
					required: ["id"]
				}
			},
			{
				name: "clear_highlight",
				description: "Clears the highlight overlay.",
				inputSchema: { type: "object", properties: {} }
			},
			{
				name: "set_object_props",
				description: "Sets transform/visibility fields on an object by UUID. Props may include x,y,scaleX,scaleY,scale,rotation,alpha,visible,name,text.",
				inputSchema: {
					type: "object",
					properties: {
						id: { type: "string" },
						props: { type: "object" }
					},
					required: ["id", "props"]
				}
			},
			{
				name: "get_object_props",
				description: "Reads transform/visibility/text props for an object UUID.",
				inputSchema: {
					type: "object",
					properties: {
						id: { type: "string" }
					},
					required: ["id"]
				}
			},
			{
				name: "find_nodes",
				description: "Query scene nodes by text/type/name/visibility. Returns matching id/path/bounds/text.",
				inputSchema: {
					type: "object",
					properties: {
						textContains: { type: "string" },
						textEquals: { type: "string" },
						typeEquals: { type: "string" },
						typeEndsWith: { type: "string" },
						nameEquals: { type: "string" },
						nameContains: { type: "string" },
						visibleOnly: { type: "boolean" },
						limit: { type: "number" }
					}
				}
			},
			{
				name: "send_input",
				description: "Inject keyboard/mouse input. Types: keyDown, keyUp, keyPress (key name or code), mouseMove, mouseDown, mouseUp, click (x/y, optional objectId for local coords).",
				inputSchema: {
					type: "object",
					properties: {
						type: { type: "string" },
						key: { type: "string" },
						keyCode: { type: "number" },
						x: { type: "number" },
						y: { type: "number" },
						button: { type: "number" },
						objectId: { type: "string" }
					},
					required: ["type"]
				}
			}
		];
	}

	static function handleToolCall(stdout: haxe.io.Output, req: Dynamic): Void {
		var name: String = req.params.name;
		var args: Dynamic = req.params.arguments != null ? req.params.arguments : {};

		if (name == "get_scene_tree" || name == "get_scene_snapshot") {
			var data = requestFromGame("GET_SCENE_SNAPSHOT");
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "get_screenshot") {
			var data = requestFromGame("GET_SCREENSHOT");
			sendResponse(stdout, req.id, { content: [{ type: "image", data: data, mimeType: "image/png" }] });
			return;
		}
		if (name == "get_object_screenshot") {
			var padding = args.paddingPx != null ? Std.int(args.paddingPx) : 0;
			var raw = requestFromGame("GET_OBJECT_SCREENSHOT:" + args.id + ":" + padding);
			var parsed: Dynamic = Json.parse(raw);
			if (parsed != null && parsed.success == true && parsed.data != null) {
				var content: Array<Dynamic> = [
					{ type: "image", data: parsed.data, mimeType: "image/png" },
					{ type: "text", text: raw }
				];
				sendResponse(stdout, req.id, { content: content });
			} else {
				sendResponse(stdout, req.id, { isError: true, content: [{ type: "text", text: raw }] });
			}
			return;
		}
		if (name == "execute_hscript") {
			var code: String = args.code;
			var codeBase64 = Base64.encode(Bytes.ofString(code));
			var data = requestFromGame("EXECUTE_HSCRIPT:" + codeBase64);
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "highlight_object") {
			var data = requestFromGame("HIGHLIGHT_OBJECT:" + args.id);
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "clear_highlight") {
			var data = requestFromGame("CLEAR_HIGHLIGHT");
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "set_object_props") {
			var payload = Json.stringify({ id: args.id, props: args.props });
			var data = requestFromGame("SET_OBJECT_PROPS:" + Base64.encode(Bytes.ofString(payload)));
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "get_object_props") {
			var data = requestFromGame("GET_OBJECT_PROPS:" + args.id);
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "find_nodes") {
			var data = requestFromGame("FIND_NODES:" + Base64.encode(Bytes.ofString(Json.stringify(args))));
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}
		if (name == "send_input") {
			var data = requestFromGame("SEND_INPUT:" + Base64.encode(Bytes.ofString(Json.stringify(args))));
			sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
			return;
		}

		sendResponse(stdout, req.id, { isError: true, content: [{ type: "text", text: "Tool not found" }] });
	}

	static function sendResponse(stdout: haxe.io.Output, id: Dynamic, result: Dynamic): Void {
		var res = { jsonrpc: "2.0", id: id, result: result };
		stdout.writeString(Json.stringify(res) + "\n");
		stdout.flush();
	}

	/** Line-protocol client against HeapsProtocolServer's agent transport (port 8080). */
	static function requestFromGame(command: String): String {
		var socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		socket.write(command + "\n");
		var result = socket.read();
		socket.close();
		return result;
	}
}
