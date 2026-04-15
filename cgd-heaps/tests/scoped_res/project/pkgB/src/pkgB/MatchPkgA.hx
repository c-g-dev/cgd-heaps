package pkgB;

@:matchResourcePath("pkgA.A")
class MatchPkgA {

	public static function valueViaLoader() {
		return hxd.Res.loader.loadScoped("value.txt").entry.getText();
	}

	public static function dupViaLoader() {
		return hxd.Res.loader.loadScoped("dup.txt").entry.getText();
	}

	public static function hasValueViaLoaderExistsScoped() {
		return hxd.Res.loader.existsScoped("value.txt");
	}

}
