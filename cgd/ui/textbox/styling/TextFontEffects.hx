package cgd.ui.textbox.styling;

import cgd.ui.SuperText;
import h2d.filter.Glow;

typedef TextFontDropShadow = {
    var dx:Float;
    var dy:Float;
    var color:Int;
    var alpha:Float;
}

typedef TextFontGlow = {
    var color:Int;
    var alpha:Float;
    var radius:Float;
    @:optional var gain:Float;
    @:optional var quality:Int;
}

typedef TextFontEffectsConfig = {
    @:optional var dropShadow:TextFontDropShadow;
    @:optional var glow:TextFontGlow;
    @:optional var bold:Bool;
}

class TextFontEffects {

    public static function apply(text:SuperText, config:TextFontEffectsConfig):Void {
        if( text == null ) throw "TextFontEffects.apply requires a non-null SuperText.";
        if( config == null ) return;

        if( config.dropShadow != null )
            text.dropShadow = config.dropShadow;

        var glowConfig = config.glow;
        if( config.bold == true ) {
            if( glowConfig == null ) {
                glowConfig = {
                    color: text.textColor,
                    alpha: 0.85,
                    radius: 0.8,
                    gain: 1.5,
                    quality: 1,
                };
            } else {
                glowConfig = {
                    color: glowConfig.color,
                    alpha: glowConfig.alpha,
                    radius: glowConfig.radius,
                    gain: glowConfig.gain != null ? glowConfig.gain * 1.25 : 1.25,
                    quality: glowConfig.quality,
                };
            }
        }

        if( glowConfig != null ) {
            text.filter = new Glow(
                glowConfig.color,
                glowConfig.alpha,
                glowConfig.radius,
                glowConfig.gain != null ? glowConfig.gain : 1.,
                glowConfig.quality != null ? glowConfig.quality : 1,
                true
            );
        }
    }

    public static function applyDropShadow(text:SuperText, dx:Float, dy:Float, color:Int, alpha:Float):Void {
        apply(text, { dropShadow: { dx: dx, dy: dy, color: color, alpha: alpha } });
    }

    public static function applyGlow(text:SuperText, color:Int, alpha:Float, radius:Float):Void {
        apply(text, { glow: { color: color, alpha: alpha, radius: radius } });
    }

    public static function applyBold(text:SuperText):Void {
        apply(text, { bold: true });
    }

}
