package cgd;

import h2d.Bitmap;
import h2d.Font;
import h2d.Tile;

typedef RichTextEffect = RichTextEffectTarget -> RichTextEffectInstance;
typedef RichTextEffectRender = RichTextEffectTarget -> Void;
typedef RichTextEffectUpdate = (target:RichTextEffectTarget, dt:Float, elapsed:Float) -> Void;

class RichTextEffectGlyph {

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

class RichTextEffectTarget {

	public var effectName(default, null) : String;
	public var attributes(default, null) : Map<String, String>;
	public var text(default, null) : String;
	public var glyphs(default, null) : Array<RichTextEffectGlyph>;

	public function new(
		effectName:String,
		attributes:Map<String, String>,
		text:String,
		glyphs:Array<RichTextEffectGlyph>
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

class RichTextEffectInstance {

	public var isAnimated : Bool;
	public var onRender : Null<RichTextEffectRender>;
	public var onUpdate : Null<RichTextEffectUpdate>;

	public function new(
		?isAnimated:Bool = false,
		?onRender:RichTextEffectRender,
		?onUpdate:RichTextEffectUpdate
	) {
		this.onRender = onRender;
		this.onUpdate = onUpdate;
		this.isAnimated = isAnimated || onUpdate != null;
	}

}

class RichTextLibrary {

	var fonts : Map<String, Font>;
	var images : Map<String, Tile>;
	var effects : Map<String, RichTextEffect>;

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

	public inline function getEffects() : Map<String, RichTextEffect> {
		return effects;
	}

	public inline function registerFont(name:String, font:Font) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerFont requires a non-empty name.";
		if( font == null ) throw 'RichTextLibrary.registerFont("${name}") received null font.';
		fonts.set(name, font);
		return this;
	}

	public inline function registerImage(name:String, tile:Tile) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerImage requires a non-empty name.";
		if( tile == null ) throw 'RichTextLibrary.registerImage("${name}") received null tile.';
		images.set(name, tile);
		return this;
	}

	public inline function registerEffect(name:String, effect:RichTextEffect) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerEffect requires a non-empty name.";
		if( effect == null ) throw 'RichTextLibrary.registerEffect("${name}") received null effect.';
		effects.set(name, effect);
		return this;
	}

}
/*package cgd;

import h2d.Bitmap;
import h2d.Font;
import h2d.Tile;

typedef RichTextEffect = RichTextEffectTarget -> RichTextEffectInstance;
typedef RichTextEffectRender = RichTextEffectTarget -> Void;
typedef RichTextEffectUpdate = (target:RichTextEffectTarget, dt:Float, elapsed:Float) -> Void;

class RichTextEffectGlyph {

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

class RichTextEffectTarget {

	public var effectName(default, null) : String;
	public var attributes(default, null) : Map<String, String>;
	public var text(default, null) : String;
	public var glyphs(default, null) : Array<RichTextEffectGlyph>;

	public function new(
		effectName:String,
		attributes:Map<String, String>,
		text:String,
		glyphs:Array<RichTextEffectGlyph>
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

class RichTextEffectInstance {

	public var isAnimated : Bool;
	public var onRender : Null<RichTextEffectRender>;
	public var onUpdate : Null<RichTextEffectUpdate>;

	public function new(
		?isAnimated:Bool = false,
		?onRender:RichTextEffectRender,
		?onUpdate:RichTextEffectUpdate
	) {
		this.onRender = onRender;
		this.onUpdate = onUpdate;
		this.isAnimated = isAnimated || onUpdate != null;
	}

}

class RichTextLibrary {

	var fonts : Map<String, Font>;
	var images : Map<String, Tile>;
	var effects : Map<String, RichTextEffect>;

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

	public inline function getEffects() : Map<String, RichTextEffect> {
		return effects;
	}

	public inline function registerFont(name:String, font:Font) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerFont requires a non-empty name.";
		if( font == null ) throw 'RichTextLibrary.registerFont("${name}") received null font.';
		fonts.set(name, font);
		return this;
	}

	public inline function registerImage(name:String, tile:Tile) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerImage requires a non-empty name.";
		if( tile == null ) throw 'RichTextLibrary.registerImage("${name}") received null tile.';
		images.set(name, tile);
		return this;
	}

	public inline function registerEffect(name:String, effect:RichTextEffect) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerEffect requires a non-empty name.";
		if( effect == null ) throw 'RichTextLibrary.registerEffect("${name}") received null effect.';
		effects.set(name, effect);
		return this;
	}

}
package cgd;

import h2d.Bitmap;
import h2d.Font;
import h2d.Tile;

typedef RichTextEffect = RichTextEffectTarget -> RichTextEffectInstance;
typedef RichTextEffectRender = RichTextEffectTarget -> Void;
typedef RichTextEffectUpdate = (target:RichTextEffectTarget, dt:Float, elapsed:Float) -> Void;

class RichTextEffectGlyph {

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

class RichTextEffectTarget {

	public var effectName(default, null) : String;
	public var attributes(default, null) : Map<String, String>;
	public var text(default, null) : String;
	public var glyphs(default, null) : Array<RichTextEffectGlyph>;

	public function new(
		effectName:String,
		attributes:Map<String, String>,
		text:String,
		glyphs:Array<RichTextEffectGlyph>
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

class RichTextEffectInstance {

	public var isAnimated : Bool;
	public var onRender : Null<RichTextEffectRender>;
	public var onUpdate : Null<RichTextEffectUpdate>;

	public function new(
		?isAnimated:Bool = false,
		?onRender:RichTextEffectRender,
		?onUpdate:RichTextEffectUpdate
	) {
		this.onRender = onRender;
		this.onUpdate = onUpdate;
		this.isAnimated = isAnimated || onUpdate != null;
	}

}

class RichTextLibrary {

	var fonts : Map<String, Font>;
	var images : Map<String, Tile>;
	var effects : Map<String, RichTextEffect>;

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

	public inline function getEffects() : Map<String, RichTextEffect> {
		return effects;
	}

	public inline function registerFont(name:String, font:Font) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerFont requires a non-empty name.";
		if( font == null ) throw 'RichTextLibrary.registerFont("${name}") received null font.';
		fonts.set(name, font);
		return this;
	}

	public inline function registerImage(name:String, tile:Tile) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerImage requires a non-empty name.";
		if( tile == null ) throw 'RichTextLibrary.registerImage("${name}") received null tile.';
		images.set(name, tile);
		return this;
	}

	public inline function registerEffect(name:String, effect:RichTextEffect) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerEffect requires a non-empty name.";
		if( effect == null ) throw 'RichTextLibrary.registerEffect("${name}") received null effect.';
		effects.set(name, effect);
		return this;
	}

}
package cgd;

import h2d.Font;
import h2d.Tile;

typedef RichTextEffect = RichTextEffectTarget -> RichTextEffectInstance;
typedef RichTextEffectRender = RichTextEffectTarget -> Float -> String;
typedef RichTextEffectUpdate = RichTextEffectTarget -> Float -> Float -> Void;

class RichTextLibrary {

	var fonts : Map<String, Font> = [];
	var images : Map<String, Tile> = [];
	var effects : Map<String, RichTextEffect> = [];

	public function new() {
	}

	public inline function getFonts() : Map<String, Font> {
		return fonts;
	}

	public inline function getImages() : Map<String, Tile> {
		return images;
	}

	public inline function getEffects() : Map<String, RichTextEffect> {
		return effects;
	}

	public inline function registerFont(name : String, font : Font) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerFont requires a non-empty name.";
		if( font == null ) throw 'RichTextLibrary.registerFont("${name}") received null font.';
		fonts.set(name, font);
		return this;
	}

	public inline function registerImage(name : String, tile : Tile) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerImage requires a non-empty name.";
		if( tile == null ) throw 'RichTextLibrary.registerImage("${name}") received null tile.';
		images.set(name, tile);
		return this;
	}

	public inline function registerEffect(name : String, effect : RichTextEffect) : RichTextLibrary {
		if( name == null || name == "" ) throw "RichTextLibrary.registerEffect requires a non-empty name.";
		if( effect == null ) throw 'RichTextLibrary.registerEffect("${name}") received null effect.';
		effects.set(name, effect);
		return this;
	}
}

class RichTextEffectTarget {

	public var index(default, null) : Int;
	public var effectName(default, null) : String;
	public var xmlNode(default, null) : Xml;
	public var renderedHtml(default, null) : String = "";

	public function new(index : Int, effectName : String, xmlNode : Xml) {
		if( xmlNode == null ) throw "RichTextEffectTarget requires a non-null xmlNode.";
		this.index = index;
		this.effectName = effectName;
		this.xmlNode = xmlNode;
	}

	public inline function getAttribute(name : String) : String {
		return xmlNode.get(name);
	}

	public function getInnerHtml() : String {
		var out = "";
		for( child in xmlNode ) out += child.toString();
		return out;
	}

	public inline function setRenderedHtml(html : String) : Void {
		renderedHtml = html;
	}
}

class RichTextEffectInstance {

	public var isAnimated(default, null) : Bool;
	public var onUpdate(default, null) : RichTextEffectUpdate;

	var renderFn : RichTextEffectRender;

	public function new(render : RichTextEffectRender, ?isAnimated = false, ?onUpdate : RichTextEffectUpdate) {
		if( render == null ) throw "RichTextEffectInstance requires a non-null render function.";
		this.renderFn = render;
		this.isAnimated = isAnimated;
		this.onUpdate = onUpdate;
	}

	public inline function render(target : RichTextEffectTarget, time : Float) : String {
		return renderFn(target, time);
	}
}
*/
