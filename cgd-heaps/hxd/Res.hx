package hxd;

#if !macro
@:build(hxd.res.ScopedRes.buildRes())
#end
class Res {

	#if !macro
	public static function load(name:String) {
		return loader.load(name);
	}
	#end

	public static macro function initEmbed(?options:haxe.macro.Expr.ExprOf<hxd.res.EmbedOptions>) {
		return hxd.res.ScopedRes.initEmbed(options);
	}

	public static macro function initLocal( ?configuration : haxe.macro.Expr.ExprOf<String> ) {
		return hxd.res.ScopedRes.initLocal(configuration);
	}

	public static macro function initPak( ?file : haxe.macro.Expr.ExprOf<String> ) {
		return hxd.res.ScopedRes.initPak(file);
	}

	public static macro function pakManifest() {
		return hxd.res.ScopedRes.pakManifest();
	}

}
