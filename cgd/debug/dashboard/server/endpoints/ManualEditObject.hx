package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import cgd.debug.dashboard.util.Highlighter;
import cgd.debug.dashboard.util.RunOnUIThread;

class ManualEditObject implements IHeapsDebugEndpoint {
	public var method(default, null): String = "POST";
	public var path(default, null): String = "/manualedit";

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new ManualEditObject());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var id = req.body == null ? "" : StringTools.trim(req.body);
		if (id == "") {
			HeapsDebugServer.getApp().s2d.addChild(new RunOnUIThread(() -> {
				Highlighter.setManualEdit(null);
			}));
			return {
				status: 200,
				contentType: "text/plain; charset=utf-8",
				body: "Disabled"
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

		HeapsDebugServer.getApp().s2d.addChild(new RunOnUIThread(() -> {
			Highlighter.setManualEdit(target);
		}));
		return {
			status: 200,
			contentType: "text/plain; charset=utf-8",
			body: "OK"
		};
	}
}

