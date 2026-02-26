package ;

import hxd.Key;
import cgd.ui.SuperTextLibrary;
import cgd.ui.SuperText;
import cgd.ui.SuperTextTypewriter;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterDeallocateLinesEffect;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterRequest;
import h2d.Font;
import hxd.App;
import hxd.Timer;
import cgd.ui.SuperTextLibrary.SuperTextEffectInstance;


class Main extends App {
	var st: SuperText;
	var typewriter: SuperTextTypewriter;

	static function main() {
		new Main();
	}

	override function init() {
		hxd.Res.initEmbed();
		var lib = new SuperTextLibrary();
		SuperText.configurable = lib;

		var font : Font = hxd.res.DefaultFont.get();
		lib.registerFont("default", font);
		lib.registerFont("vl-gothic", hxd.Res.VL_Gothic_Regular.toFont());

		lib.registerImage("heart", hxd.Res.emoji_u2764.toTile());

		lib.registerEffect("wave", function(target) {
			var amp = Std.parseFloat(target.getAttribute("amp", "6"));
			var speed = Std.parseFloat(target.getAttribute("speed", "6"));
			var phase = Std.parseFloat(target.getAttribute("phase", "0.45"));
			return new SuperTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
				for( glyph in updateTarget.glyphs ) {
					var offset = Math.sin(elapsed * speed + glyph.index * phase) * amp;
					glyph.bitmap.y = glyph.baseY + offset;
				}
			});
		});
		lib.registerEffect("rainbow", function(target) {
			var speed = Std.parseFloat(target.getAttribute("speed", "1.8"));
			var phase = Std.parseFloat(target.getAttribute("phase", "0.6"));
			var saturation = Std.parseFloat(target.getAttribute("saturation", "0.9"));
			var value = Std.parseFloat(target.getAttribute("value", "1.0"));
			return new SuperTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
				for( glyph in updateTarget.glyphs ) {
					var hue = wrap01(elapsed * speed + Math.sin(elapsed * speed + glyph.index * phase) * 0.5);
					var rgb = hsvToRgb(hue, saturation, value);
					glyph.bitmap.color.set(rgb.r, rgb.g, rgb.b, glyph.bitmap.color.a);
				}
			});
		});
		lib.registerEffect("pulse", function(target) {
			var speed = Std.parseFloat(target.getAttribute("speed", "2.4"));
			var amount = Std.parseFloat(target.getAttribute("amount", "0.06"));
			var phase = Std.parseFloat(target.getAttribute("phase", "0.12"));
			return new SuperTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
				for( glyph in updateTarget.glyphs ) {
					glyph.bitmap.smooth = true;
					var scale = 1 + Math.sin(elapsed * speed + glyph.index * phase) * amount;
					glyph.bitmap.scaleX = scale;
					glyph.bitmap.scaleY = scale;
					var tile = glyph.bitmap.tile;
					glyph.bitmap.x = glyph.baseX - (tile.width * (scale - 1)) * 0.5;
					glyph.bitmap.y = glyph.baseY - (tile.height * (scale - 1)) * 0.5;
				}
			});
		});

		st = new SuperText(font, s2d);
		st.x = 40;
		st.y = 80;
		//st.scale(4);
		st.fontName = "vl-gothic";
		st.maxWidth = 340;
		st.text = '<p>Effects demo: ' + st.img("heart") + st.img("heart") + st.img("heart") + ' <effect name="wave" amp="8" speed="5.5" phase="0.55">WAVE</effect>, <effect name="rainbow" speed="1.8" phase="0.6">RAINBOW</effect>, and <effect name="pulse" speed="2.5" amount="0.05">PULSE</effect> in <speed val="1">paragraph</speed> one. Test test test test test test test test test test.</p><p>Paragraph two keeps writing after deallocating lines.</p><p>Paragraph three validates finish flow.</p>';
		typewriter = st.createTypewriter(
			44,
			3,
			WaitForAdvance,
			typewriterController,
			SlideLinesUp(320)
		);
		typewriter.start().then(function(_) {
			trace("Wave smoke test typewriter finished.");
		});
	}

	function typewriterController(state:SuperTextTypewriterOnFrameState):SuperTextTypewriterRequest {
		return switch( state ) {
			case Writing:{ if(Key.isDown(Key.SPACE)) return AutoFill; else return Wait; }
			case AllLinesAllocated:{ if(Key.isDown(Key.SPACE)) return Advance; else return Wait; }
			case DeallocatingLines:{ return Wait; }
			case ParagraphBreak:{ return if(Key.isDown(Key.SPACE)) Advance; else Wait; }
			case NoMoreParagraphs:{ return Finish; }
		}
	}


	static inline function wrap01(v:Float):Float {
		var f = v - Math.floor(v);
		return f < 0 ? f + 1 : f;
	}

	static function hsvToRgb(h:Float, s:Float, v:Float):{ r:Float, g:Float, b:Float } {
		var hh = wrap01(h) * 6;
		var i = Std.int(Math.floor(hh));
		var f = hh - i;
		var p = v * (1 - s);
		var q = v * (1 - f * s);
		var t = v * (1 - (1 - f) * s);
		return switch( i % 6 ) {
		case 0: { r: v, g: t, b: p };
		case 1: { r: q, g: v, b: p };
		case 2: { r: p, g: v, b: t };
		case 3: { r: p, g: q, b: v };
		case 4: { r: t, g: p, b: v };
		default: { r: v, g: p, b: q };
		}
	}
}