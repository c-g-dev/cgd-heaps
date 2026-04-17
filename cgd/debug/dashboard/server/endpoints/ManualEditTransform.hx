package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import cgd.debug.dashboard.util.ManualEdit;
import haxe.Json;

class ManualEditTransform implements IHeapsDebugEndpoint {
	public var method(default, null):String = "GET";
	public var path(default, null):String = "/manualedit/transform";

	public static function register():Void {
		HeapsDebugServer.registerEndpoint(new ManualEditTransform());
	}

	public function new() {}

	public function handle(server:HeapsDebugServer, req:HeapsDebugRequest):HeapsDebugResponse {
		var target = ManualEdit.getTarget();
		if (target == null) {
			return {
				status: 200,
				contentType: "application/json; charset=utf-8",
				body: '{"active":false}'
			};
		}

		var data:Dynamic = {
			active: true,
			x: target.x,
			y: target.y,
			sx: target.scaleX,
			sy: target.scaleY,
			rotation: target.rotation
		};
		return {
			status: 200,
			contentType: "application/json; charset=utf-8",
			body: Json.stringify(data)
		};
	}
}
