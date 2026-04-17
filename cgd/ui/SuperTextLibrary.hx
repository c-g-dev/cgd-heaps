package cgd.ui;

import h2d.Bitmap;
import h2d.Font;
import h2d.Tile;

typedef SuperTextEffect = SuperTextEffectTarget -> SuperTextEffectInstance;
typedef SuperTextEffectRender = SuperTextEffectTarget -> Void;
typedef SuperTextEffectUpdate = (target:SuperTextEffectTarget, dt:Float, elapsed:Float) -> Void;

class SuperTextEffectGlyph {

	public var bitmap(default, null) : Bitmap;
	public var index(default, null) : Int;
	public var charCode(default, null) : Int;
	public var baseX(default, null) : Float;
	public var baseY(default, null) : Float;

	public function new(bitmap:Bitmap, index:Int, charCode:Int, baseX:Float, baseY:Float) {
		this.bitmap = bitmap;
		this.index = index;
		this.charCode = charCode;
		this.baseX = baseX;
		this.baseY = baseY;
	}

}

class SuperTextEffectTarget {

	public var effectName(default, null) : String;
	public var attributes(default, null) : Map<String, String>;
	public var text(default, null) : String;
	public var glyphs(default, null) : Array<SuperTextEffectGlyph>;

	public function new(
		effectName:String,
		attributes:Map<String, String>,
		text:String,
		glyphs:Array<SuperTextEffectGlyph>
	) {
		this.effectName = effectName;
		this.attributes = attributes == null ? [] : attributes;
		this.text = text == null ? "" : text;
		this.glyphs = glyphs == null ? [] : glyphs;
	}

	public inline function getAttribute(name:String, ?defaultValue:String) : String {
		if( name == null ) return defaultValue;
		var value = attributes.get(name);
		return value == null ? defaultValue : value;
	}

}

class SuperTextEffectInstance {

	public var isAnimated : Bool;
	public var onRender : Null<SuperTextEffectRender>;
	public var onUpdate : Null<SuperTextEffectUpdate>;

	public function new(
		?isAnimated:Bool = false,
		?onRender:SuperTextEffectRender,
		?onUpdate:SuperTextEffectUpdate
	) {
		this.onRender = onRender;
		this.onUpdate = onUpdate;
		this.isAnimated = isAnimated || onUpdate != null;
	}

}

class SuperTextLibrary {

	var fonts : Map<String, Font>;
	var images : Map<String, Tile>;
	var effects : Map<String, SuperTextEffect>;

	public function new() {
		fonts = [];
		images = [];
		effects = [];
	}

	public inline function getFonts() : Map<String, Font> {
		return fonts;
	}

	public inline function getImages() : Map<String, Tile> {
		return images;
	}

	public inline function getEffects() : Map<String, SuperTextEffect> {
		return effects;
	}

	public inline function registerFont(name:String, font:Font) : SuperTextLibrary {
		if( name == null || name == "" ) throw "SuperTextLibrary.registerFont requires a non-empty name.";
		if( font == null ) throw 'SuperTextLibrary.registerFont("${name}") received null font.';
		fonts.set(name, font);
		return this;
	}

	public inline function registerImage(name:String, tile:Tile) : SuperTextLibrary {
		if( name == null || name == "" ) throw "SuperTextLibrary.registerImage requires a non-empty name.";
		if( tile == null ) throw 'SuperTextLibrary.registerImage("${name}") received null tile.';
		images.set(name, tile);
		return this;
	}

	public inline function registerEffect(name:String, effect:SuperTextEffect) : SuperTextLibrary {
		if( name == null || name == "" ) throw "SuperTextLibrary.registerEffect requires a non-empty name.";
		if( effect == null ) throw 'SuperTextLibrary.registerEffect("${name}") received null effect.';
		effects.set(name, effect);
		return this;
	}

}
