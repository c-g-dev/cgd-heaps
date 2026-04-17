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
			if (Reflect.hasField(data, "x")) obj.x = Reflect.field(data, "x");
			if (Reflect.hasField(data, "y")) obj.y = Reflect.field(data, "y");
			if (Reflect.hasField(data, "scaleX")) obj.scaleX = Reflect.field(data, "scaleX");
			if (Reflect.hasField(data, "scaleY")) obj.scaleY = Reflect.field(data, "scaleY");
			if (Reflect.hasField(data, "rotation")) obj.rotation = Reflect.field(data, "rotation");
		}
	}
}
