package cgd.utils;

import h2d.Object;
import hxd.res.Resource;
import haxe.Json;

class TransformUtils {

	public static function patch(obj: Object, jsonResource: Dynamic): Void {
		var data: Dynamic = null;

		if (Std.isOfType(jsonResource, String)) {
			data = Json.parse(cast jsonResource);
		} else if (Std.isOfType(jsonResource, Resource)) {
			var res: Resource = cast jsonResource;
			data = Json.parse(res.entry.getBytes().toString());
		} else if (Reflect.hasField(jsonResource, "toText")) {
			var text: String = Reflect.callMethod(jsonResource, Reflect.field(jsonResource, "toText"), []);
			data = Json.parse(text);
		} else {
			data = jsonResource;
		}

		if (data != null) {
			apply(obj, data);
		}
	}

	public static function serialize(obj: Object): Dynamic {
		return {
			x: obj.x,
			y: obj.y,
			scaleX: obj.scaleX,
			scaleY: obj.scaleY,
			rotation: obj.rotation,
			alpha: obj.alpha,
			visible: obj.visible
		};
	}

	public static function apply(obj: Object, data: Dynamic): Void {
		if (Reflect.hasField(data, "x")) obj.x = Reflect.field(data, "x");
		if (Reflect.hasField(data, "y")) obj.y = Reflect.field(data, "y");
		if (Reflect.hasField(data, "scaleX")) obj.scaleX = Reflect.field(data, "scaleX");
		if (Reflect.hasField(data, "scaleY")) obj.scaleY = Reflect.field(data, "scaleY");
		if (Reflect.hasField(data, "rotation")) obj.rotation = Reflect.field(data, "rotation");
		if (Reflect.hasField(data, "alpha")) obj.alpha = Reflect.field(data, "alpha");
		if (Reflect.hasField(data, "visible")) obj.visible = Reflect.field(data, "visible");
	}

	public static function fieldsEqual(a: Dynamic, b: Dynamic): Bool {
		if (a == null || b == null) {
			return a == b;
		}

		for (field in ["x", "y", "scaleX", "scaleY", "rotation", "alpha", "visible"]) {
			var av = Reflect.hasField(a, field) ? Reflect.field(a, field) : null;
			var bv = Reflect.hasField(b, field) ? Reflect.field(b, field) : null;
			if (av != bv) {
				return false;
			}
		}
		return true;
	}
}
