package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.server.EmbeddedAssets;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;

class ServeUI implements IHeapsDebugEndpoint {
	public var method(default, null): String = "GET";
	public var path(default, null): String = "/ui.js";

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new ServeUI());
	}

	public function new() {}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var js = EmbeddedAssets.uiJs;
		return {
			status: 200,
			contentType: "application/javascript; charset=utf-8",
			body: js
		};
	}
}


