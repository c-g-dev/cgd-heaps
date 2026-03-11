package cgd.ui.textbox.styling;

import cgd.Behavior;
import cgd.ui.textbox.Textbox;
import cgd.coro.Future;

class BasicOpenCloseEffect extends Behavior {

    static inline var CLOSED:Int = 0;
    static inline var OPEN:Int = 255;
    static inline var STEP_PER_FRAME:Int = 24;

    var textBox:Textbox;
    var baseScaleY:Float;
    var openY:Float;
    var openness:Int;
    var targetOpenness:Int;
    var completion:Null<Future>;
    var removeOnComplete:Bool;

    private function new(textBox:Textbox) {
        super();
        if( textBox == null ) throw "BasicOpenCloseEffect requires a non-null textbox.";

        this.textBox = textBox;
        baseScaleY = textBox.scaleY;
        openY = textBox.y;
        openness = CLOSED;
        targetOpenness = CLOSED;
        completion = null;
        removeOnComplete = false;
        setOpenness(openness);

        onFrame = onBehaviorFrame;
    }

    public static function apply(textBox:Textbox):Void {
        if( textBox == null ) throw "BasicOpenCloseEffect.apply requires a non-null textbox.";

        var effect = new BasicOpenCloseEffect(textBox);
        textBox.addChild(effect);

        textBox.open = function():Future {
            return effect.open();
        };

        textBox.isOpen = function():Bool {
            return effect.isOpen();
        };

        textBox.isClosed = function():Bool {
            return effect.isClosed();
        };

        textBox.close = function():Future {
            return effect.close();
        };
    }

    function open():Future {
        return startTransition(OPEN, false);
    }

    function close():Future {
        return startTransition(CLOSED, true);
    }

    function isOpen():Bool {
        return openness == OPEN;
    }

    function isClosed():Bool {
        return openness == CLOSED;
    }

    function startTransition(target:Int, shouldRemoveOnComplete:Bool):Future {
        targetOpenness = target;
        removeOnComplete = shouldRemoveOnComplete;

        if( openness == targetOpenness ) {
            if( removeOnComplete ) {
                removeOnComplete = false;
                textBox.remove();
            }
            return Future.immediate();
        }

        if( completion != null && !completion.isComplete )
            completion.resolve(null);

        completion = new Future();
        return completion;
    }

    function onBehaviorFrame(_:Float):Void {
        if( openness == targetOpenness ) return;

        if( targetOpenness > openness )
            setOpenness(openness + STEP_PER_FRAME);
        else
            setOpenness(openness - STEP_PER_FRAME);

        if( openness == targetOpenness )
            finalizeTransition();
    }

    function finalizeTransition():Void {
        var finished = completion;
        completion = null;

        if( removeOnComplete ) {
            removeOnComplete = false;
            textBox.remove();
        }

        if( finished != null && !finished.isComplete )
            finished.resolve(null);
    }

    function getWindowHeight():Float {
        var bounds = textBox.getBounds(textBox);
        return bounds.height;
    }

    function updateBaseScaleYFromCurrentState():Void {
        var ratio = openness / OPEN;
        if( ratio > 0 ) baseScaleY = textBox.scaleY / ratio;
    }

    function setOpenness(value:Float):Void {
        var clamped = Std.int(hxd.Math.clamp(value, CLOSED, OPEN));
        updateBaseScaleYFromCurrentState();

        var height = getWindowHeight();
        var halfOpenHeight = height * baseScaleY * 0.5;

        openness = clamped;
        var ratio = openness / OPEN;
        textBox.scaleY = baseScaleY * ratio;
        textBox.y = openY + (halfOpenHeight * (1 - ratio));
        textBox.set("openness", openness);
    }

}
