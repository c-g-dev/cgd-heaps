package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import cgd.debug.DequeuedDispatcher;
import cgd.debug.dashboard.util.Highlighter;

class HighlightObject implements IHeapsDebugEndpoint {
	public var method(default, null): String = "POST";
	public var path(default, null): String = "/highlightobject";

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new HighlightObject());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var id = req.body == null ? "" : StringTools.trim(req.body);
		if (id == "") {
			return {
				status: 400,
				contentType: "text/plain; charset=utf-8",
				body: "Missing object id in request body"
			};
		}

		var registry = HeapsDebugServer.getLastScene2DRegistry();
		var target = registry == null ? null : registry.idToObject.get(id);
		if (target == null) {
			return {
				status: 404,
				contentType: "text/plain; charset=utf-8",
				body: "Object not found"
			};
		}

		DequeuedDispatcher.runOnMain(() -> {
			Highlighter.highlight(target);
		});

		return {
			status: 200,
			contentType: "text/plain; charset=utf-8",
			body: "OK"
		};
	}
}


