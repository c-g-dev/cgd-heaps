package cgd;

import h2d.Text.Align;
import h2d.Bitmap;
import h2d.Font;
import h2d.Font.FontType;
import h2d.HtmlText;
import h2d.Interactive;
import h2d.Object;
import h2d.Tile;
import h2d.TileGroup;
import cgd.RichTextLibrary.RichTextEffect;
import cgd.RichTextLibrary.RichTextEffectGlyph;
import cgd.RichTextLibrary.RichTextEffectInstance;
import cgd.RichTextLibrary.RichTextEffectTarget;

private typedef RichTextLineInfo = {
	var width : Float;
	var height : Float;
	var baseLine : Float;
	var baseLineOffset : Float;
}

private typedef RichTextSplitNode = {
	var node : Xml;
	var prevChar : Int;
	var pos : Int;
	var width : Float;
	var height : Float;
	var baseLine : Float;
	var baseLineOffset : Float;
	var font : Font;
}

private typedef RichTextEffectBuildContext = {
	var effectName : String;
	var effect : RichTextEffect;
	var attributes : Map<String, String>;
	var glyphs : Array<RichTextEffectGlyph>;
	var textBuffer : StringBuf;
}

private typedef RichTextActiveEffect = {
	var target : RichTextEffectTarget;
	var instance : RichTextEffectInstance;
	var elapsed : Float;
}

class RichText extends HtmlText {

	public static var configurable : RichTextLibrary = new RichTextLibrary();

	public var htmlText(get, set) : String;
	public var fontName(get, set) : String;

	var internalHtmlText : String = "<p></p>";
	var currentFontName : Null<String>;
	var bypassAutoWrap : Bool = false;
	var effectStack : Array<RichTextEffectBuildContext> = [];
	var activeEffects : Array<RichTextActiveEffect> = [];

	public function new(font:Font, ?parent:Object) {
		super(font, parent);
	}

	public inline function img(name:String) : String {
		if( name == null || name == "" ) throw "RichText.img requires a non-empty image name.";
		return '<img src="' + name + '"/>';
	}

	public function setFontName(name:String) : Font {
		if( name == null || name == "" ) throw "RichText.setFontName requires a non-empty name.";
		currentFontName = name;
		return super.set_font(requireRegisteredFont(name));
	}

	override function set_font(value:Font) {
		var dynamicValue : Dynamic = value;
		if( Std.isOfType(dynamicValue, String) ) {
			var name : String = cast dynamicValue;
			currentFontName = name;
			return super.set_font(requireRegisteredFont(name));
		}
		currentFontName = null;
		return super.set_font(value);
	}

	override public dynamic function formatText(text:String) : String {
		var normalized = text == null ? "null" : text;
		if( bypassAutoWrap ) {
			internalHtmlText = normalized;
			return normalized;
		}
		internalHtmlText = "<p>" + normalized + "</p>";
		return internalHtmlText;
	}

	function get_htmlText() : String {
		return internalHtmlText;
	}

	function set_htmlText(value:String) : String {
		var normalized = value == null ? "<p>null</p>" : value;
		bypassAutoWrap = true;
		super.set_text(normalized);
		bypassAutoWrap = false;
		internalHtmlText = normalized;
		return normalized;
	}

	function get_fontName() : String {
		return currentFontName;
	}

	function set_fontName(value:String) : String {
		setFontName(value);
		return value;
	}

	override public dynamic function loadFont(name:String) : Font {
		if( name != null && configurable != null ) {
			var fonts = configurable.getFonts();
			if( fonts != null ) {
				var font = fonts.get(name);
				if( font != null ) return font;
			}
		}
		var fallback = HtmlText.defaultLoadFont(name);
		if( fallback == null ) return this.font;
		return fallback;
	}

	override public dynamic function loadImage(url:String) : Tile {
		if( url != null && configurable != null ) {
			var images = configurable.getImages();
			if( images != null ) {
				var image = images.get(url);
				if( image != null ) return image;
			}
		}
		return HtmlText.defaultLoadImage(url);
	}

	override function validateText() {
		@:privateAccess {
			textXml = parseText(text);
			validateNodes(textXml);
		}
		validateEffectNodes(@:privateAccess textXml);
	}

	override function initGlyphs(text:String, rebuild = true) {
		if( rebuild ) {
			@:privateAccess glyphs.clear();
			@:privateAccess for( e in elements ) e.remove();
			@:privateAccess elements = [];
			activeEffects = [];
		}
		effectStack = [];
		@:privateAccess glyphs.setDefaultColor(textColor);

		var doc : Xml;
		@:privateAccess {
			if( textXml == null ) doc = parseText(text) else doc = textXml;
		}

		@:privateAccess {
			yPos = 0;
			xMax = 0;
			xMin = Math.POSITIVE_INFINITY;
			sizePos = 0;
			calcYMin = 0;
		}

		var metrics : Array<RichTextLineInfo> = [makeRichLineInfo(0, font.lineHeight, font.baseLine)];
		@:privateAccess prevChar = -1;
		@:privateAccess newLine = true;
		var splitNode : RichTextSplitNode = {
			node: null,
			pos: 0,
			font: font,
			prevChar: -1,
			width: 0,
			height: 0,
			baseLine: 0,
			baseLineOffset: 0,
		};
		for( e in doc )
			@:privateAccess this.buildSizes(e, font, cast metrics, cast splitNode);

		var max = 0.;
		for( info in metrics ) {
			if( info.width > max ) max = info.width;
		}
		@:privateAccess calcWidth = max;

		@:privateAccess prevChar = -1;
		@:privateAccess newLine = true;
		@:privateAccess nextLine(textAlign, metrics[0].width);
		for( e in doc )
			addRichNode(e, font, textAlign, rebuild, metrics);

		@:privateAccess if( xPos > xMax ) xMax = xPos;
		@:privateAccess textXml = null;

		@:privateAccess {
			var y = yPos;
			calcXMin = xMin;
			calcWidth = xMax - xMin;
			calcHeight = y + metrics[sizePos].height - calcYMin;
			calcSizeHeight = y + metrics[sizePos].baseLine;
			calcDone = true;
			if( rebuild ) needsRebuild = false;
		}
	}

	 function onUpdate(dt:Float) {
		//super.onUpdate(dt);
		for( effect in activeEffects ) {
			if( effect.instance.onUpdate == null ) continue;
			effect.elapsed += dt;
			effect.instance.onUpdate(effect.target, dt, effect.elapsed);
		}
	}

	inline function makeRichLineInfo(width:Float, height:Float, baseLine:Float, offset = 0.) : RichTextLineInfo {
		return { width: width, height: height, baseLine: baseLine, baseLineOffset: offset };
	}

	function addRichNode(e:Xml, font:Font, align:Align, rebuild:Bool, metrics:Array<RichTextLineInfo>) {
		function createInteractive() {
			@:privateAccess if( aHrefs == null || aHrefs.length == 0 ) return;
			@:privateAccess aInteractive = new Interactive(0, metrics[@:privateAccess sizePos].baseLine, this);
			@:privateAccess aInteractive.propagateEvents = propagateInteractiveNode;
			@:privateAccess var href = aHrefs[aHrefs.length - 1];
			@:privateAccess aInteractive.onClick = function(event) {
				onHyperlink(href);
			}
			@:privateAccess aInteractive.onOver = function(event) {
				onOverHyperlink(href);
			}
			@:privateAccess aInteractive.onOut = function(event) {
				onOutHyperlink(href);
			}
			@:privateAccess aInteractive.x = xPos;
			@:privateAccess aInteractive.y = yPos;
			@:privateAccess elements.push(aInteractive);
		}

		inline function finalizeInteractive() {
			@:privateAccess if( aInteractive != null ) {
				aInteractive.width = xPos - aInteractive.x;
				aInteractive = null;
			}
		}

		inline function makeLineBreak() {
			finalizeInteractive();
			@:privateAccess if( xPos > xMax ) xMax = xPos;
			@:privateAccess yPos += metrics[sizePos].height + lineSpacing;
			@:privateAccess nextLine(align, metrics[++sizePos].width);
			createInteractive();
		}

		if( e.nodeType == Xml.Element ) {
			var prevColor = null;
			var prevGlyphs = null;
			var oldAlign = align;
			var nodeName = e.nodeName.toLowerCase();
			inline function setFont(v:String) {
				font = loadFont(v);
				@:privateAccess if( prevGlyphs == null ) prevGlyphs = glyphs;
				@:privateAccess var previousGlyphs = glyphs;
				@:privateAccess glyphs = new TileGroup(font == null ? null : font.tile, this);
				if( font != null ) {
					switch( font.type ) {
					case SignedDistanceField(channel, alphaCutoff, smoothing):
						var shader = new h3d.shader.SignedDistanceField();
						shader.channel = channel;
						shader.alphaCutoff = alphaCutoff;
						shader.smoothing = smoothing;
						shader.autoSmoothing = smoothing == -1;
						@:privateAccess glyphs.smooth = this.smooth;
						@:privateAccess glyphs.addShader(shader);
					default:
					}
				}
				@:privateAccess glyphs.curColor.load(previousGlyphs.curColor);
				@:privateAccess elements.push(glyphs);
			}
			var tag = @:privateAccess this.resolveHtmlTag(nodeName);
			if( tag != null ) {
				if( tag.font != null ) setFont(tag.font);
				if( tag.color != null ) {
					@:privateAccess if( prevColor == null ) prevColor = glyphs.curColor.clone();
					@:privateAccess glyphs.setDefaultColor(tag.color);
				}
			}
			switch( nodeName ) {
			case "effect":
				beginEffectContext(e);
			case "font":
				for( a in e.attributes() ) {
					var v = e.get(a);
					switch( a.toLowerCase() ) {
					case "color":
						@:privateAccess if( prevColor == null ) prevColor = glyphs.curColor.clone();
						if( v.length == 4 && StringTools.fastCodeAt(v, 0) == '#'.code )
							v = "#" + v.charAt(1) + v.charAt(1) + v.charAt(2) + v.charAt(2) + v.charAt(3) + v.charAt(3);
						@:privateAccess glyphs.setDefaultColor(Std.parseInt("0x" + v.substr(1)));
					case "opacity":
						@:privateAccess if( prevColor == null ) prevColor = glyphs.curColor.clone();
						@:privateAccess glyphs.curColor.a *= Std.parseFloat(v);
					case "face":
						setFont(v);
					default:
					}
				}
			case "p":
				for( a in e.attributes() ) {
					switch( a.toLowerCase() ) {
					case "align":
						var v = e.get(a);
						if( v != null ) {
							switch( v.toLowerCase() ) {
							case "left":
								align = Left;
							case "center":
								align = Center;
							case "right":
								align = Right;
							case "multiline-center":
								align = MultilineCenter;
							case "multiline-right":
								align = MultilineRight;
							default:
							}
						}
					default:
					}
				}
				@:privateAccess if( !newLine ) {
					makeLineBreak();
					newLine = true;
					prevChar = -1;
				} else {
					nextLine(align, metrics[sizePos].width);
				}
			case "b", "bold":
				if( tag?.font == null ) setFont("bold");
			case "i", "italic":
				if( tag?.font == null ) setFont("italic");
			case "br":
				makeLineBreak();
				@:privateAccess newLine = true;
				@:privateAccess prevChar = -1;
			case "img":
				var i : Tile = loadImage(e.get("src"));
				if( i == null ) i = Tile.fromColor(0xFF00FF, 8, 8);
				@:privateAccess var py = yPos;
				switch( imageVerticalAlign ) {
				case Bottom:
					@:privateAccess py += metrics[sizePos].baseLine - i.height;
				case Middle:
					@:privateAccess py += ((metrics[sizePos].baseLine + metrics[sizePos].baseLineOffset) - i.height) * 0.5;
				case Top:
				}
				@:privateAccess if( py + i.dy < calcYMin ) calcYMin = py + i.dy;
				if( rebuild ) {
					var b = new Bitmap(i, this);
					@:privateAccess b.x = xPos;
					b.y = py;
					@:privateAccess elements.push(b);
				}
				@:privateAccess newLine = false;
				@:privateAccess prevChar = -1;
				@:privateAccess xPos += i.width + imageSpacing;
			case "a":
				if( e.exists("href") ) {
					finalizeInteractive();
					@:privateAccess if( aHrefs == null ) aHrefs = [];
					@:privateAccess aHrefs.push(e.get("href"));
					createInteractive();
				}
			default:
			}
			for( child in e )
				addRichNode(child, font, align, rebuild, metrics);
			align = oldAlign;
			switch( nodeName ) {
			case "effect":
				endEffectContext(rebuild);
			case "p":
				@:privateAccess if( newLine ) {
					nextLine(align, metrics[sizePos].width);
				} else if( sizePos < metrics.length - 2 || metrics[sizePos + 1].width != 0 ) {
					makeLineBreak();
					newLine = true;
					prevChar = -1;
				}
			case "a":
				@:privateAccess if( aHrefs.length > 0 ) {
					finalizeInteractive();
					aHrefs.pop();
					createInteractive();
				}
			default:
			}
			@:privateAccess if( prevGlyphs != null ) glyphs = prevGlyphs;
			@:privateAccess if( prevColor != null ) glyphs.curColor.load(prevColor);
		} else if( e.nodeValue.length != 0 ) {
			@:privateAccess newLine = false;
			var t = e.nodeValue;
			@:privateAccess var dy = metrics[sizePos].baseLine - font.baseLine;
			var currentEffect = currentEffectContext();
			for( i in 0...t.length ) {
				var cc = StringTools.fastCodeAt(t, i);
				if( cc == "\n".code ) {
					if( currentEffect != null ) currentEffect.textBuffer.addChar(cc);
					makeLineBreak();
					@:privateAccess dy = metrics[sizePos].baseLine - font.baseLine;
					@:privateAccess prevChar = -1;
					continue;
				}
				if( currentEffect != null ) currentEffect.textBuffer.addChar(cc);
				var fc = font.getChar(cc);
				if( fc != null ) {
					@:privateAccess xPos += fc.getKerningOffset(prevChar);
					if( rebuild ) {
						if( currentEffect == null ) {
							@:privateAccess glyphs.add(xPos, yPos + dy, fc.t);
						} else {
							var glyph = new Bitmap(fc.t, this);
							@:privateAccess glyph.x = xPos;
							glyph.y = @:privateAccess yPos + dy;
							var color = @:privateAccess glyphs.curColor;
							glyph.color.set(color.r, color.g, color.b, color.a);
							@:privateAccess elements.push(glyph);
							currentEffect.glyphs.push(new RichTextEffectGlyph(glyph, currentEffect.glyphs.length, cc, glyph.x, glyph.y));
						}
					}
					@:privateAccess if( yPos == 0 && fc.t.dy + dy < calcYMin ) calcYMin = fc.t.dy + dy;
					@:privateAccess xPos += fc.width + letterSpacing;
				}
				@:privateAccess prevChar = cc;
			}
		}
	}

	function validateEffectNodes(xml:Xml) : Void {
		switch( xml.nodeType ) {
		case Element:
			if( xml.nodeName.toLowerCase() == "effect" ) {
				var effectName = xml.get("name");
				if( effectName == null || effectName == "" )
					throw 'RichText <effect> tag requires a non-empty "name" attribute.';
				if( resolveRegisteredEffect(effectName) == null )
					throw 'RichText effect "${effectName}" is not registered.';
			}
			for( child in xml )
				validateEffectNodes(child);
		case Document:
			for( child in xml )
				validateEffectNodes(child);
		default:
		}
	}

	function beginEffectContext(node:Xml) : Void {
		var effectName = node.get("name");
		if( effectName == null || effectName == "" )
			throw 'RichText <effect> tag requires a non-empty "name" attribute.';
		var effect = resolveRegisteredEffect(effectName);
		if( effect == null )
			throw 'RichText effect "${effectName}" is not registered.';
		effectStack.push({
			effectName: effectName,
			effect: effect,
			attributes: extractAttributes(node),
			glyphs: [],
			textBuffer: new StringBuf(),
		});
	}

	function endEffectContext(rebuild:Bool) : Void {
		var context = effectStack.pop();
		if( context == null || !rebuild ) return;
		var target = new RichTextEffectTarget(
			context.effectName,
			context.attributes,
			context.textBuffer.toString(),
			context.glyphs
		);
		var instance = context.effect(target);
		if( instance == null ) return;
		if( instance.onRender != null ) instance.onRender(target);
		if( instance.isAnimated && instance.onUpdate != null ) {
			activeEffects.push({
				target: target,
				instance: instance,
				elapsed: 0.,
			});
		}
	}

	inline function currentEffectContext() : RichTextEffectBuildContext {
		if( effectStack.length == 0 ) return null;
		return effectStack[effectStack.length - 1];
	}

	function extractAttributes(node:Xml) : Map<String, String> {
		var attributes : Map<String, String> = [];
		for( name in node.attributes() )
			attributes.set(name, node.get(name));
		return attributes;
	}

	function resolveRegisteredEffect(name:String) : RichTextEffect {
		if( name == null || configurable == null ) return null;
		var effects = configurable.getEffects();
		if( effects == null ) return null;
		return effects.get(name);
	}

	function requireRegisteredFont(name:String) : Font {
		if( name == null || name == "" ) throw "RichText requires a non-empty registered font name.";
		if( configurable == null ) throw "RichText.configurable is null.";
		var fonts = configurable.getFonts();
		if( fonts == null ) throw "RichText.configurable fonts map is null.";
		var resolved = fonts.get(name);
		if( resolved == null ) throw 'RichText font "${name}" is not registered.';
		return resolved;
	}

}
