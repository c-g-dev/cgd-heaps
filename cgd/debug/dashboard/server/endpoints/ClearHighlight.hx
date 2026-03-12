package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import cgd.debug.dashboard.util.RunOnUIThread;
import cgd.debug.dashboard.util.Highlighter;

class ClearHighlight implements IHeapsDebugEndpoint {
	public var method(default, null): String = "POST";
	public var path(default, null): String = "/highlight/clear";

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new ClearHighlight());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		HeapsDebugServer.getApp().s2d.addChild(new RunOnUIThread(() -> {
			Highlighter.clear();
		}));
		return {
			status: 200,
			contentType: "text/plain; charset=utf-8",
			body: "OK"
		};
	}
}


