package cgd.ui.panel.styling;

import cgd.Behavior;
import cgd.ui.panel.Panel;
import cgd.coro.Future;

class BasicOpenCloseEffect extends Behavior {

    static inline var CLOSED:Int = 0;
    static inline var OPEN:Int = 255;
    static inline var STEP_PER_FRAME:Int = 24;

    var panel:Panel;
    var baseScaleY:Float;
    var openY:Float;
    var openness:Int;
    var targetOpenness:Int;
    var completion:Null<Future>;
    var removeOnComplete:Bool;

    private function new(panel:Panel) {
        super();
        if( panel == null ) throw "BasicOpenCloseEffect requires a non-null panel.";

        this.panel = panel;
        baseScaleY = panel.scaleY;
        openY = panel.y;
        openness = CLOSED;
        targetOpenness = CLOSED;
        completion = null;
        removeOnComplete = false;
        setOpenness(openness);

        onFrame = onBehaviorFrame;
    }

    public static function apply(panel:Panel):Void {
        if( panel == null ) throw "BasicOpenCloseEffect.apply requires a non-null panel.";

        var effect = new BasicOpenCloseEffect(panel);
        panel.addChild(effect);

        panel.open = function():Future {
            return effect.open();
        };

        panel.isOpen = function():Bool {
            return effect.isOpen();
        };

        panel.isClosed = function():Bool {
            return effect.isClosed();
        };

        panel.close = function():Future {
            return effect.close();
        };
    }

    function open():Future {
        panel.notifyOpened();
        return startTransition(OPEN, false);
    }

    function close():Future {
        panel.notifyClosed();
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
                panel.remove();
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
            panel.remove();
        }

        if( finished != null && !finished.isComplete )
            finished.resolve(null);
    }

    function getPanelHeight():Float {
        var bounds = panel.getBounds(panel);
        return bounds.height;
    }

    function updateBaseScaleYFromCurrentState():Void {
        var ratio = openness / OPEN;
        if( ratio > 0 ) baseScaleY = panel.scaleY / ratio;
    }

    function setOpenness(value:Float):Void {
        var clamped = Std.int(hxd.Math.clamp(value, CLOSED, OPEN));
        updateBaseScaleYFromCurrentState();

        var height = getPanelHeight();
        var halfOpenHeight = height * baseScaleY * 0.5;

        openness = clamped;
        var ratio = openness / OPEN;
        panel.scaleY = baseScaleY * ratio;
        panel.y = openY + (halfOpenHeight * (1 - ratio));
        panel.set("openness", openness);
    }

}
