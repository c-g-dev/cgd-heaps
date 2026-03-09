class Main extends hxd.App {

	override function init() {
		super.init();
		#if test_embed
		hxd.Res.initEmbed();
		#elseif test_pak
		hxd.Res.initPak("tests/scoped_res/out/res");
		#else
		hxd.Res.initLocal();
		#end

		expect("pkgA.value", clean(pkgA.A.value()), "pkgA_value");
		expect("pkgA.shared", clean(pkgA.A.shared()), "root_shared");
		expect("pkgA.dup", clean(pkgA.A.dup()), "pkgA_dup");
		expect("pkgA.dupViaLoader", clean(pkgA.A.dupViaLoader()), "pkgA_dup");
		expect("pkgA.valueViaImportedRes", clean(pkgA.A.valueViaImportedRes()), "pkgA_value");
		expect("pkgA.dupViaImportedLoader", clean(pkgA.A.dupViaImportedLoader()), "pkgA_dup");
		expectBool("pkgA.hasValueViaLoaderExists", pkgA.A.hasValueViaLoaderExists(), true);
		expectBool("pkgA.hasValueViaLoaderExistsScoped", pkgA.A.hasValueViaLoaderExistsScoped(), true);
		expect("pkgB.shared", clean(pkgB.B.shared()), "root_shared");
		expect("pkgB.dup", clean(pkgB.B.dup()), "root_dup");
		expect("pkgB.dupViaLoader", clean(pkgB.B.dupViaLoader()), "root_dup");
		expectBool("pkgB.hasValueViaLoaderExists", pkgB.B.hasValueViaLoaderExists(), false);
		expectBool("pkgB.hasValueViaLoaderExistsScoped", pkgB.B.hasValueViaLoaderExistsScoped(), false);

		trace("ok");

		s2d.addChild(new h2d.Bitmap(hxd.Res.sticker1.toTile()));
	}

	static function expect( label : String, actual : String, expected : String ) {
		if( actual != expected )
			throw label + " mismatch, expected=" + expected + " actual=" + actual;
	}

	static function expectBool( label : String, actual : Bool, expected : Bool ) {
		if( actual != expected )
			throw label + " mismatch, expected=" + expected + " actual=" + actual;
	}

	static function clean( s : String ) {
		return StringTools.trim(s);
	}

	static function main() {
		new Main();
	}

}
