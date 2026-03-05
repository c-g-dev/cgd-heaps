package cgd.ui.textbox.styling;

import cgd.ui.textbox.Textbox;
import heaps.coroutine.Future;

class BasicOpenCloseEffect {

    public static function apply(textBox:Textbox):Void {
        if( textBox == null ) throw "BasicOpenCloseEffect.apply requires a non-null textbox.";

        var baseScaleY = textBox.scaleY;
        var openness:Int = textBox.alpha <= 0 ? 0 : 255;

        function getWindowHeight():Float {
            var bounds = textBox.getBounds(textBox);
            return bounds.height;
        }

        function updateBaseScaleYFromCurrentState():Void {
            var ratio = openness / 255;
            if( ratio > 0 ) baseScaleY = textBox.scaleY / ratio;
        }

        function setOpenness(value:Float):Void {
            var clamped = Std.int(hxd.Math.clamp(value, 0, 255));
            updateBaseScaleYFromCurrentState();

            var height = getWindowHeight();
            var previousRatio = openness / 255;
            var originY = textBox.y - (height * baseScaleY * 0.5 * (1 - previousRatio));

            openness = clamped;
            var ratio = openness / 255;
            textBox.scaleY = baseScaleY * ratio;
            textBox.y = originY + (height * baseScaleY * 0.5 * (1 - ratio));
            textBox.set("openness", openness);
        }

        function isOpen():Bool {
            return openness >= 255;
        }

        function isClosed():Bool {
            return openness <= 0;
        }

        setOpenness(openness);

        textBox.open = function():Future {
            if( !isOpen() ) setOpenness(255);
            textBox.alpha = 1;
            return Future.immediate();
        };

        textBox.close = function():Future {
            if( !isClosed() ) setOpenness(0);
            textBox.destroy();
            return Future.immediate();
        };
    }

}
