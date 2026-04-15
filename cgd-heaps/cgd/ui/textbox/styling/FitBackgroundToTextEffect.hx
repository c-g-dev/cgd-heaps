package cgd.ui.textbox.styling;

import cgd.Behavior;
import cgd.ui.textbox.Textbox;

/**
	Resizes the textbox background every frame to fit the current text dimensions,
	using the text object's x/y position as symmetric horizontal and vertical padding.

	Intended to be combined with `AlignmentEffect` (called after this effect is applied
	so that alignment uses the updated bounds).
**/
class FitBackgroundToTextEffect extends Behavior {

    var textbox:Textbox;
    var bg:h2d.Bitmap;
    var originalTileWidth:Float;
    var originalTileHeight:Float;

    private function new(textbox:Textbox, bg:h2d.Bitmap) {
        super();
        this.textbox = textbox;
        this.bg = bg;
        originalTileWidth = bg.tile.width;
        originalTileHeight = bg.tile.height;
        onFrame = onBehaviorFrame;
        resize();
    }

    public static function apply(textbox:Textbox):Void {
        if( textbox == null ) throw "FitBackgroundToTextEffect.apply requires a non-null textbox.";
        var bg = textbox.getBackground();
        if( bg == null ) throw "FitBackgroundToTextEffect.apply requires the textbox to have a background.";
        textbox.addChild(new FitBackgroundToTextEffect(textbox, bg));
    }

    function onBehaviorFrame(_:Float):Void {
        resize();
    }

    function resize():Void {
        var text = textbox.getSuperText();
        var paddingX = text.x;
        var paddingY = text.y;
        var desiredWidth = paddingX + text.textWidth + paddingX;
        var desiredHeight = paddingY + text.textHeight + paddingY;
        bg.scaleX = desiredWidth / originalTileWidth;
        bg.scaleY = desiredHeight / originalTileHeight;
    }

}
