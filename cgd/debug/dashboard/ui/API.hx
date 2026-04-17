package cgd.debug.dashboard.ui;

@:keep
@:expose("HDS")
class API {
	public static function updateObjectField(objectId:String, fieldName:String, value:Dynamic):Void {
		UpdateObjectField.run(objectId, fieldName, value);
	}
}


