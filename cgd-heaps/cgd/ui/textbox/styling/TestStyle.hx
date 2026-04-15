package cgd.ui.textbox.styling;

import cgd.ui.textbox.TextboxStyles;
import cgd.ui.textbox.TextboxStyles.TextboxStyle;

class TestStyle {

    public static inline var NAME:String = "TestStyle";
    static inline var PADDING:Float = 25;
    static inline var HEIGHT_RATIO:Float = 0.25;
    static inline var MAX_LINES:Int = 2;

    public static function create():TextboxStyle {
        var style = new TextboxStyle();

        var background = hxd.Res.textbox.toTile();
        var targetHeight = hxd.Window.getInstance().height * HEIGHT_RATIO;
       // background.scaleToSize(background.width, targetHeight);

        style.background = background;
        style.font = hxd.Res.fonts.vlgothic.VL_Gothic_Regular.toFont();
        style.textAreaX = PADDING;
        style.textAreaY = PADDING;
        style.textAreaWidth = background.width - (PADDING * 2);
        style.maxLines = MAX_LINES;
        style.addOnInit(function(textbox) {
            AlignmentEffect.toBottom(textbox);
            BasicOpenCloseEffect.apply(textbox);
        });

        return style;
    }

    public static function register():Void {
        TextboxStyles.register(NAME, create());
    }

}
