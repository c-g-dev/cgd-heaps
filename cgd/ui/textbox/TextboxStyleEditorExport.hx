package cgd.ui.textbox;

import cgd.GlobalFonts;
import cgd.ui.SuperText;
import cgd.ui.panel.PanelStyles;
import cgd.ui.panel.PanelStyles.PanelStyle;
import cgd.ui.panel.PanelStyles.PanelSizing;
import h2d.Text.Align;
import h2d.Tile;

typedef TextboxStyleEditorExportOptions = {
    @:optional var name:String;
    @:optional var className:String;
    @:optional var assetBasename:String;
    @:optional var presetBackground:String;
    @:optional var demoLines:Array<String>;
    @:optional var includeLaunchDemo:Bool;
}

class TextboxStyleEditorExport {

    public static function export(style:TextboxStyle, ?textbox:Textbox, ?options:TextboxStyleEditorExportOptions):Dynamic {
        if( style == null ) throw "TextboxStyleEditorExport.export requires a non-null style.";

        var window = hxd.Window.getInstance();
        var panel = style.panelStyle;
        if( panel == null ) throw "TextboxStyleEditorExport.export requires panelStyle.";

        var assetBasename = options != null && options.assetBasename != null
            ? options.assetBasename
            : resolveAssetBasename(style.background != null ? style.background : panel.background);

        var presetBackground = options != null && options.presetBackground != null
            ? options.presetBackground
            : assetBasename;

        var className = options != null && options.className != null ? options.className : "ImportedStyle";
        var name = options != null && options.name != null ? options.name : classNameToRegistryName(className);

        var widthMode = "full";
        var widthRatio = 1.0;
        var heightRatio = 0.25;

        switch( panel.sizing ) {
        case Fixed(fixedWidth, fixedHeight):
            widthRatio = window.width > 0 ? fixedWidth / window.width : 1.0;
            heightRatio = window.height > 0 ? fixedHeight / window.height : 0.25;
            widthMode = widthRatio >= 0.999 ? "full" : "ratio";
        default:
        }

        var fontInfo = resolveFontInfo(style);
        var paddingInfo = resolvePaddingInfo(style, panel, fontInfo.font);
        var borderInfo = resolveBorderInfo(panel);

        var alignBottom = false;
        var centerHorizontally = false;
        var textColor = 0xFFFFFF;
        var textAlign = "left";
        var openCloseEffect = false;
        var fontDropShadow = false;
        var fontDropShadowDx = 2.;
        var fontDropShadowDy = 2.;
        var fontDropShadowColor = 0x000000;
        var fontDropShadowAlpha = 0.6;
        var fontGlow = false;
        var fontGlowColor = 0xFFFFFF;
        var fontGlowAlpha = 0.75;
        var fontGlowRadius = 2.;
        var fontBold = false;
        var charFadeIn = false;
        var charFadeDuration = 0.12;

        if( textbox != null ) {
            var tbPanel = textbox.getPanel();
            if( tbPanel != null ) {
                alignBottom = Math.abs(textbox.y - (window.height - tbPanel.height)) < 2;
                centerHorizontally = Math.abs(textbox.x - Math.round((window.width - tbPanel.width) * 0.5)) < 2;
            }

            var text = textbox.getSuperText();
            textColor = text.textColor;
            textAlign = switch( text.textAlign ) {
                case Center: "center";
                case Right: "right";
                default: "left";
            };

            openCloseEffect = hasOpenCloseEffect(textbox);

            var fontEffects = readFontEffects(text);
            fontDropShadow = fontEffects.fontDropShadow;
            fontDropShadowDx = fontEffects.fontDropShadowDx;
            fontDropShadowDy = fontEffects.fontDropShadowDy;
            fontDropShadowColor = fontEffects.fontDropShadowColor;
            fontDropShadowAlpha = fontEffects.fontDropShadowAlpha;
            fontGlow = fontEffects.fontGlow;
            fontGlowColor = fontEffects.fontGlowColor;
            fontGlowAlpha = fontEffects.fontGlowAlpha;
            fontGlowRadius = fontEffects.fontGlowRadius;
            fontBold = fontEffects.fontBold;
        }

        charFadeIn = style.charFadeDuration > 0;
        charFadeDuration = style.charFadeDuration > 0 ? style.charFadeDuration : 0.12;

        return {
            name: name,
            className: className,
            assetBasename: assetBasename != null ? assetBasename : "",
            backgroundPath: null,
            presetBackground: presetBackground,
            useScaleGrid: panel.useScaleGrid,
            widthMode: widthMode,
            widthRatio: widthRatio,
            heightRatio: heightRatio,
            centerHorizontally: centerHorizontally,
            maxLines: style.maxLines > 0 ? style.maxLines : 3,
            fontName: fontInfo.fontName,
            fontDefaultSize: fontInfo.fontDefaultSize,
            fontScale: fontInfo.fontScale,
            textColor: textColor,
            textAlign: textAlign,
            paddingMode: paddingInfo.paddingMode,
            padding: paddingInfo.padding,
            scaleBorder: paddingInfo.scaleBorder,
            safeInset: paddingInfo.safeInset,
            paddingTopOffset: paddingInfo.paddingTopOffset,
            usePerEdgePadding: paddingInfo.usePerEdgePadding,
            paddingEdges: paddingInfo.paddingEdges,
            border: borderInfo.border,
            usePerEdgeBorder: borderInfo.usePerEdgeBorder,
            borderEdges: borderInfo.borderEdges,
            alignBottom: alignBottom,
            openCloseEffect: openCloseEffect,
            fontDropShadow: fontDropShadow,
            fontDropShadowDx: fontDropShadowDx,
            fontDropShadowDy: fontDropShadowDy,
            fontDropShadowColor: fontDropShadowColor,
            fontDropShadowAlpha: fontDropShadowAlpha,
            fontGlow: fontGlow,
            fontGlowColor: fontGlowColor,
            fontGlowAlpha: fontGlowAlpha,
            fontGlowRadius: fontGlowRadius,
            fontBold: fontBold,
            charFadeIn: charFadeIn,
            charFadeDuration: charFadeDuration,
            includeLaunchDemo: options != null && options.includeLaunchDemo != null ? options.includeLaunchDemo : true,
            demoLines: options != null && options.demoLines != null ? options.demoLines : defaultDemoLines(),
        };
    }

    static function defaultDemoLines():Array<String> {
        return [
            '<p align="left">Line one of the demo textbox style.</p>',
            '<p align="left">A second page checks padding inside the frame.</p>',
            '<p align="left">Final demo line. Press ENTER after it finishes to cycle.</p>'
        ];
    }

    static function classNameToRegistryName(className:String):String {
        var base = className;
        if( StringTools.endsWith(base, "Style") )
            base = base.substring(0, base.length - 5);
        if( base.length == 0 ) return "imported-style";

        var result = "";
        for( i in 0...base.length ) {
            var ch = base.charAt(i);
            if( ch == ch.toUpperCase() && i > 0 )
                result += "-";
            result += ch.toLowerCase();
        }
        return result;
    }

    static function resolveAssetBasename(tile:Null<Tile>):Null<String> {
        if( tile == null ) return null;

        for( field in Reflect.fields(hxd.Res) ) {
            var value = Reflect.field(hxd.Res, field);
            if( !Std.isOfType(value, hxd.res.Image) ) continue;
            var image:hxd.res.Image = cast value;
            if( image.toTile() == tile )
                return field;
        }

        return null;
    }

    static function resolveFontInfo(style:TextboxStyle):{ fontName:String, fontDefaultSize:Bool, fontScale:Float, font:h2d.Font } {
        if( style.fontName != null ) {
            var named = style.font != null ? style.font : GlobalFonts.MPLUS2_Medium.toFont();
            return {
                fontName: style.fontName,
                fontDefaultSize: Math.abs(named.scale - 1.0) < 0.01,
                fontScale: named.scale,
                font: named
            };
        }

        if( style.font == null )
            throw "TextboxStyleEditorExport.export requires font or fontName.";

        for( globalFont in GlobalFonts.all() ) {
            var defaultFont = globalFont.toFont();
            defaultFont.toDefaultSize();
            if( fontsMatch(defaultFont, style.font) ) {
                return {
                    fontName: globalFont,
                    fontDefaultSize: true,
                    fontScale: 1.0,
                    font: style.font
                };
            }

            var scaledCandidate = globalFont.toFont();
            scaledCandidate.scale = style.font.scale;
            if( fontsMatch(scaledCandidate, style.font) ) {
                return {
                    fontName: globalFont,
                    fontDefaultSize: false,
                    fontScale: style.font.scale,
                    font: style.font
                };
            }
        }

        return {
            fontName: GlobalFonts.MPLUS2_Medium,
            fontDefaultSize: Math.abs(style.font.scale - 1.0) < 0.01,
            fontScale: style.font.scale,
            font: style.font
        };
    }

    static function fontsMatch(a:h2d.Font, b:h2d.Font):Bool {
        return Math.abs(a.lineHeight - b.lineHeight) < 0.5
            && Math.abs(a.baseLine - b.baseLine) < 0.5;
    }

    static function resolvePaddingInfo(style:TextboxStyle, panel:PanelStyle, font:h2d.Font):Dynamic {
        var pl = panel.paddingLeft;
        var pr = panel.paddingRight;
        var pt = panel.paddingTop;
        var pb = panel.paddingBottom;

        var uniform = pl == pr && pl == pt && pl == pb;
        var uniformBorder = panel.borderLeft == panel.borderRight
            && panel.borderLeft == panel.borderTop
            && panel.borderLeft == panel.borderBottom;
        var border = panel.borderLeft;

        var looksLikeFrame = !uniform
            || (uniformBorder && border > 0 && (pl != pb || Math.abs(pt - (border + (pl - border))) > 1.0));

        if( !looksLikeFrame ) {
            return {
                paddingMode: "simple",
                padding: pl,
                scaleBorder: 8,
                safeInset: 18,
                paddingTopOffset: "none",
                usePerEdgePadding: false,
                paddingEdges: emptyEdges()
            };
        }

        var scaleBorder = uniformBorder ? border : panel.borderLeft;
        var safeInset = uniform ? Math.max(0, pl - scaleBorder) : 18;
        var paddingTopOffset = "none";

        if( uniform && pt < pb - 0.5 ) {
            var lineHeight = font.lineHeight;
            var paddingH = scaleBorder + safeInset;
            if( Math.abs(pt - (paddingH - lineHeight)) < 1.5 )
                paddingTopOffset = "minusLineHeight";
        }

        var usePerEdgePadding = !uniform;
        return {
            paddingMode: "frame",
            padding: pl,
            scaleBorder: scaleBorder,
            safeInset: safeInset,
            paddingTopOffset: paddingTopOffset,
            usePerEdgePadding: usePerEdgePadding,
            paddingEdges: usePerEdgePadding ? {
                left: pl,
                right: pr,
                top: pt,
                bottom: pb
            } : emptyEdges()
        };
    }

    static function resolveBorderInfo(panel:PanelStyle):Dynamic {
        var uniform = panel.borderLeft == panel.borderRight
            && panel.borderLeft == panel.borderTop
            && panel.borderLeft == panel.borderBottom;

        if( uniform ) {
            return {
                border: panel.borderLeft,
                usePerEdgeBorder: false,
                borderEdges: emptyEdges()
            };
        }

        return {
            border: panel.borderLeft,
            usePerEdgeBorder: true,
            borderEdges: {
                left: panel.borderLeft,
                right: panel.borderRight,
                top: panel.borderTop,
                bottom: panel.borderBottom
            }
        };
    }

    static function emptyEdges():Dynamic {
        return { left: null, right: null, top: null, bottom: null };
    }

    static function hasOpenCloseEffect(textbox:Textbox):Bool {
        return textbox.get("openness") != null;
    }

    static function readFontEffects(text:SuperText):Dynamic {
        var fontDropShadow = false;
        var fontDropShadowDx = 2.;
        var fontDropShadowDy = 2.;
        var fontDropShadowColor = 0x000000;
        var fontDropShadowAlpha = 0.6;
        var fontGlow = false;
        var fontGlowColor = 0xFFFFFF;
        var fontGlowAlpha = 0.75;
        var fontGlowRadius = 2.;
        var fontBold = false;

        if( text.dropShadow != null ) {
            fontDropShadow = true;
            fontDropShadowDx = text.dropShadow.dx;
            fontDropShadowDy = text.dropShadow.dy;
            fontDropShadowColor = text.dropShadow.color;
            fontDropShadowAlpha = text.dropShadow.alpha;
        }

        var glow = Std.downcast(text.filter, h2d.filter.Glow);
        if( glow != null ) {
            if( glow.color == text.textColor && glow.radius <= 1.2 ) {
                fontBold = true;
            } else {
                fontGlow = true;
                fontGlowColor = glow.color;
                fontGlowAlpha = glow.alpha;
                fontGlowRadius = glow.radius;
            }
        }

        return {
            fontDropShadow: fontDropShadow,
            fontDropShadowDx: fontDropShadowDx,
            fontDropShadowDy: fontDropShadowDy,
            fontDropShadowColor: fontDropShadowColor,
            fontDropShadowAlpha: fontDropShadowAlpha,
            fontGlow: fontGlow,
            fontGlowColor: fontGlowColor,
            fontGlowAlpha: fontGlowAlpha,
            fontGlowRadius: fontGlowRadius,
            fontBold: fontBold,
        };
    }

}
