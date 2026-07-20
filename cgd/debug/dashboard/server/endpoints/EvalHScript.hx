package cgd.debug.dashboard.server.endpoints;

import cgd.debug.DequeuedDispatcher;
import cgd.debug.HeapsProtocolServer;
import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import haxe.Json;
import hscript.Parser;
import sys.thread.Lock;

class EvalHScript implements IHeapsDebugEndpoint {
	public var method(default, null): String = "POST";
	public var path(default, null): String = "/eval";

	static inline var EVAL_TIMEOUT_SEC: Float = 10.0;

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new EvalHScript());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var code = req.body;
		if (code == null || code == "") {
			return {
				status: 400,
				contentType: "application/json; charset=utf-8",
				body: Json.stringify({ success: false, result: null, error: "Empty request body" })
			};
		}

		var protocol = HeapsProtocolServer.getInstance();
		var outcome: Dynamic;

		if (protocol != null) {
			outcome = protocol.runOnMainSync(function() {
				return protocol.executeHScript(code);
			});
		} else {
			outcome = runFallbackEval(code);
		}

		var ok = outcome != null && outcome.success == true;
		return {
			status: ok ? 200 : 400,
			contentType: "application/json; charset=utf-8",
			body: Json.stringify(outcome)
		};
	}

	static function runFallbackEval(code: String): Dynamic {
		var result: Dynamic = { success: false, result: null, error: "Eval did not run" };
		var lock = new Lock();
		DequeuedDispatcher.runOnMain(function() {
			result = HeapsProtocolServer.safeCall(function() {
				var parser = new Parser();
				parser.allowTypes = true;
				parser.allowJSON = true;
				var program = parser.parseString(code);
				var interp = createFallbackInterp();
				var res = interp.execute(program);
				return { success: true, result: Std.string(res), error: null };
			});
			lock.release();
		});
		if (!lock.wait(EVAL_TIMEOUT_SEC)) {
			return { success: false, result: null, error: "Timed out waiting for main thread" };
		}
		return result;
	}

	static function createFallbackInterp(): hscript.Interp {
		var app = HeapsDebugServer.getApp();
		var interp = new hscript.Interp();
		interp.variables.set("app", app);
		interp.variables.set("s2d", app.s2d);
		interp.variables.set("s3d", app.s3d);
		interp.variables.set("scene2d", app.s2d);
		interp.variables.set("scene3d", app.s3d);
		interp.variables.set("Std", Std);
		interp.variables.set("Type", Type);
		interp.variables.set("get2d", function(id: String) {
			var reg = HeapsDebugServer.getLastScene2DRegistry();
			return reg == null ? null : reg.idToObject.get(id);
		});
		return interp;
	}
}
