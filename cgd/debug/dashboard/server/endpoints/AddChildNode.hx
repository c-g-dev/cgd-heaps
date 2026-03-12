package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;
import cgd.debug.dashboard.util.RunOnUIThread;
import h2d.Bitmap;
import h2d.Object;
import h2d.Tile;
import haxe.Json;
import haxe.crypto.Base64;
import hxd.PixelFormat;
import hxd.Pixels;

class AddChildNode implements IHeapsDebugEndpoint {
	public var method(default, null):String = "POST";
	public var path(default, null):String = "/node/addchild";

	public static function register():Void {
		HeapsDebugServer.registerEndpoint(new AddChildNode());
	}

	public function new() {}

	public function handle(server:HeapsDebugServer, req:HeapsDebugRequest):HeapsDebugResponse {
		if (req.body == null || req.body == "") {
			return badRequest("Missing request body");
		}

		var payload:Dynamic = Json.parse(req.body);
		var parentIdRaw:Dynamic = Reflect.field(payload, "parentId");
		if (parentIdRaw == null) {
			return badRequest("Missing parentId");
		}
		var parentId = Std.string(parentIdRaw);
		if (parentId == "") {
			return badRequest("Invalid parentId");
		}

		var kindRaw:Dynamic = Reflect.field(payload, "kind");
		if (kindRaw == null) {
			return badRequest("Missing kind");
		}
		var kind = Std.string(kindRaw);
		if (kind != "Bitmap") {
			return badRequest("Unsupported child kind: " + kind);
		}

		var registry = HeapsDebugServer.getLastScene2DRegistry();
		var parent:Object = registry == null ? null : registry.idToObject.get(parentId);
		if (parent == null) {
			return {
				status: 404,
				contentType: "text/plain; charset=utf-8",
				body: "Parent object not found"
			};
		}

		var bitmapPayload:Dynamic = Reflect.field(payload, "bitmap");
		if (bitmapPayload == null) {
			return badRequest("Missing bitmap payload");
		}

		var width = Std.int(Reflect.field(bitmapPayload, "width"));
		var height = Std.int(Reflect.field(bitmapPayload, "height"));
		if (width <= 0 || height <= 0) {
			return badRequest("Bitmap width and height must be positive");
		}

		var pixelsBase64Raw:Dynamic = Reflect.field(bitmapPayload, "pixelsBase64");
		if (pixelsBase64Raw == null) {
			return badRequest("Missing bitmap pixelsBase64");
		}
		var pixelsBase64 = Std.string(pixelsBase64Raw);
		if (pixelsBase64 == "") {
			return badRequest("Bitmap pixel payload is empty");
		}

		var decodedPixels = Base64.decode(pixelsBase64);
		var expectedLength = width * height * 4;
		if (decodedPixels.length != expectedLength) {
			return badRequest("Bitmap pixel data length mismatch");
		}

		HeapsDebugServer.getApp().s2d.addChild(new RunOnUIThread(() -> {
			var pixels = new Pixels(width, height, decodedPixels, PixelFormat.RGBA);
			var tile = Tile.fromPixels(pixels);
			new Bitmap(tile, parent);
		}));

		return {
			status: 200,
			contentType: "application/json; charset=utf-8",
			body: '{"ok":true}'
		};
	}

	function badRequest(message:String):HeapsDebugResponse {
		return {
			status: 400,
			contentType: "text/plain; charset=utf-8",
			body: message
		};
	}
}
