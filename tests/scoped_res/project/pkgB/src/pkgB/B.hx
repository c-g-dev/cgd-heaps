package pkgB;

class B {

	public static function shared() {
		return hxd.Res.shared.entry.getText();
	}

	public static function dup() {
		return hxd.Res.dup.entry.getText();
	}

	public static function dupViaLoader() {
		return hxd.Res.loader.loadScoped("dup.txt").entry.getText();
	}

}
