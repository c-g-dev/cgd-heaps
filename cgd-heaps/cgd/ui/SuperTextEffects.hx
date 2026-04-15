package cgd.ui;

import cgd.ui.SuperTextLibrary.SuperTextEffectTarget;
import cgd.ui.SuperTextLibrary.SuperTextEffectInstance;

class SuperTextEffects {

    public static function wave(target:SuperTextEffectTarget):SuperTextEffectInstance {
        var amp = Std.parseFloat(target.getAttribute("amp", "6"));
        var speed = Std.parseFloat(target.getAttribute("speed", "6"));
        var phase = Std.parseFloat(target.getAttribute("phase", "0.45"));
        return new SuperTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
            for( glyph in updateTarget.glyphs ) {
                var offset = Math.sin(elapsed * speed + glyph.index * phase) * amp;
                glyph.bitmap.y = glyph.baseY + offset;
            }
        });
    }

    public static function rainbow(target:SuperTextEffectTarget):SuperTextEffectInstance {
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
    }
    
    

    public static function pulse(target:SuperTextEffectTarget):SuperTextEffectInstance {
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