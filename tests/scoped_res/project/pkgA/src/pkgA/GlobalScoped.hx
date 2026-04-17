package pkgA;

@:globalResourcePath
class GlobalScoped {

	public static function shared() {
		return hxd.Res.shared.entry.getText();
	}

	public static function dup() {
		return hxd.Res.dup.entry.getText();
	}

	public static function hasValueViaLoaderExistsScoped() {
		return hxd.Res.loader.existsScoped("value.txt");
	}

}
