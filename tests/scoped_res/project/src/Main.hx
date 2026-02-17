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
		expect("pkgB.shared", clean(pkgB.B.shared()), "root_shared");
		expect("pkgB.dup", clean(pkgB.B.dup()), "root_dup");

		trace("ok");

		s2d.addChild(new h2d.Bitmap(hxd.Res.sticker1.toTile()));
	}

	static function expect( label : String, actual : String, expected : String ) {
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
