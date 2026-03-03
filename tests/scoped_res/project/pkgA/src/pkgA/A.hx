package pkgA;

class A {

	public static function value() {
		return hxd.Res.value.entry.getText();
	}

	public static function shared() {
		return hxd.Res.shared.entry.getText();
	}

	public static function dup() {
		return hxd.Res.dup.entry.getText();
	}

	public static function dupViaLoader() {
		return hxd.Res.loader.loadScoped("dup.txt").entry.getText();
	}

	public static function hasValueViaLoaderExists() {
		return hxd.Res.loader.exists("value.txt");
	}

	public static function hasValueViaLoaderExistsScoped() {
		return hxd.Res.loader.existsScoped("value.txt");
	}

}
