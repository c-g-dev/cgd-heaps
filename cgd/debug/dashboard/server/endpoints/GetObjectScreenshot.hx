package cgd.debug.dashboard.server.endpoints;

import cgd.debug.HeapsProtocolServer;
import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import haxe.Json;

/**
	POST /screenshot/object — body is JSON `{ "id": "...", "padding": 0 }` or plain object id.
	Returns JSON `{ success, data (base64 png), bounds?, error? }`.
**/
class GetObjectScreenshot implements IHeapsDebugEndpoint {
	public var method(default, null): String = "POST";
	public var path(default, null): String = "/screenshot/object";

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new GetObjectScreenshot());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var id: String = null;
		var padding: Int = 0;
		var body = req.body == null ? "" : StringTools.trim(req.body);
		if (body == "") {
			return json(400, { success: false, error: "Missing object id" });
		}
		if (StringTools.startsWith(body, "{")) {
			var parsed: Dynamic = Json.parse(body);
			id = parsed.id;
			if (parsed.padding != null)
				padding = Std.int(parsed.padding);
		} else {
			id = body;
		}
		if (id == null || id == "") {
			return json(400, { success: false, error: "Missing object id" });
		}

		var protocol = HeapsProtocolServer.getInstance();
		if (protocol == null) {
			return json(500, { success: false, error: "HeapsProtocolServer not attached" });
		}
		var outcome: Dynamic = protocol.runOnMainSync(function() {
			return protocol.captureObjectScreenshotBase64(id, padding);
		});
		var ok = outcome != null && outcome.success == true;
		return json(ok ? 200 : 404, outcome);
	}

	static function json(status: Int, body: Dynamic): HeapsDebugResponse {
		return {
			status: status,
			contentType: "application/json; charset=utf-8",
			body: Json.stringify(body)
		};
	}
}
