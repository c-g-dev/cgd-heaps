package cgd.ctrl;

import hxd.Key;
import cgd.ctrl.Controller;
import cgd.ctrl.IControllerAccess;

/**
 * TAccess: the action enum used by the consumer (component or app).
 * TBase:   the action enum used by the root Controller's bindings.
 *
 * When both are the same (e.g. app creating its own access directly via
 * controller.createAccess()), actionMapper is null and actions pass through.
 *
 * When a component uses Controls.get(), TAccess is the component's local enum
 * and actionMapper translates it to TBase before querying bindings.
 */
class ControllerAccess<TAccess:Int = Int, TBase:Int = Int> implements IControllerAccess {
    public var controller(default, null):Controller<TBase>;

    public var disableRumble(get, set):Bool;
    public var rumbleMultiplicator(get, set):Float;

    var destroyed(get, never):Bool;
    var actionMapper:Null<TAccess->TBase>;
    var lockedUntilS:Float = -1.0;
    var postLockUntilS:Float = -1.0;
    var holdTimeS:Map<TAccess, Float> = new Map();
    var autoFireFirstDone:Map<TAccess, Bool> = new Map();
    var autoFireNextS:Map<TAccess, Float> = new Map();
    var consumedActions:Map<TAccess, Int> = new Map();

    @:allow(cgd.ctrl.Controller)
    @:allow(cgd.ctrl.Controls)
    function new(controller:Controller<TBase>, ?actionMapper:TAccess->TBase) {
        this.controller = controller;
        this.actionMapper = actionMapper;
        controller.registerAccess(this);
    }

    inline function get_destroyed():Bool {
        return controller == null || controller.destroyed;
    }

    inline function get_disableRumble():Bool {
        return destroyed ? false : controller.disableRumble;
    }

    inline function set_disableRumble(value:Bool):Bool {
        if (!destroyed) {
            controller.disableRumble = value;
        }
        return get_disableRumble();
    }

    inline function get_rumbleMultiplicator():Float {
        return destroyed ? 0.0 : controller.rumbleMultiplicator;
    }

    inline function set_rumbleMultiplicator(value:Float):Float {
        if (!destroyed) {
            controller.rumbleMultiplicator = value;
        }
        return get_rumbleMultiplicator();
    }

    public function dispose():Void {
        if (controller != null) {
            controller.unregisterAccess(this);
        }
        controller = null;
    }

    @:keep public function toString():String {
        return 'ControllerAccess[ $controller ]' + (!isActive() ? "<LOCKED>" : "");
    }

    public function isActive():Bool {
        if (destroyed) {
            return false;
        }

        var now = haxe.Timer.stamp();
        var dynamicLock = lockCondition();
        if (dynamicLock) {
            postLockUntilS = now + 0.06;
            return false;
        }

        if (postLockUntilS >= 0 && now < postLockUntilS) {
            return false;
        }

        if (lockedUntilS >= 0 && now < lockedUntilS) {
            return false;
        }

        return controller.exclusive == null || controller.exclusive == this;
    }

    inline function mapAction(action:TAccess):TBase {
        return actionMapper != null ? actionMapper(action) : cast action;
    }

    public function getAnalogValue(action:TAccess):Float {
        if (!isActive()) {
            return 0.0;
        }

        var actionBindings = controller.bindings.get(mapAction(action));
        if (actionBindings == null) {
            return 0.0;
        }

        for (binding in actionBindings) {
            var value = binding.getValue(controller.pad);
            if (value != 0.0) {
                return value;
            }
        }

        return 0.0;
    }

    public inline function getAnalogValue2(negativeAction:TAccess, positiveAction:TAccess):Float {
        return -Math.abs(getAnalogValue(negativeAction)) + Math.abs(getAnalogValue(positiveAction));
    }

    public inline function getAnalogAngleXY(xAxisAction:TAccess, yAxisAction:TAccess):Float {
        return Math.atan2(getAnalogValue(yAxisAction), getAnalogValue(xAxisAction));
    }

    public inline function getAnalogAngle4(leftAction:TAccess, rightAction:TAccess, upAction:TAccess, downAction:TAccess):Float {
        return Math.atan2(
            getAnalogValue2(upAction, downAction),
            getAnalogValue2(leftAction, rightAction)
        );
    }

    public inline function getAnalogDistXY(xAction:TAccess, ?yAction:TAccess, clamp:Bool = true):Float {
        if (yAction == null) {
            return Math.abs(getAnalogValue(xAction));
        }

        var dist = getDistance(0, 0, getAnalogValue(xAction), getAnalogValue(yAction));
        return clamp ? Math.min(dist, 1.0) : dist;
    }

    public inline function getAnalogDist4(leftAction:TAccess, rightAction:TAccess, upAction:TAccess, downAction:TAccess, clamp:Bool = true):Float {
        var dist = getDistance(
            0,
            0,
            getAnalogValue2(leftAction, rightAction),
            getAnalogValue2(upAction, downAction)
        );
        return clamp ? Math.min(dist, 1.0) : dist;
    }

    public inline function getAnalogDist2(negativeAction:TAccess, positiveAction:TAccess):Float {
        return Math.abs(getAnalogValue2(negativeAction, positiveAction));
    }

    public function isDown(action:TAccess):Bool {
        if (!isActive()) {
            return false;
        }

        var actionBindings = controller.bindings.get(mapAction(action));
        if (actionBindings == null) {
            return false;
        }

        for (binding in actionBindings) {
            if (binding.isDown(controller.pad)) {
                return true;
            }
        }

        return false;
    }

    public function peekPressed(action:TAccess):Bool {
        if (!isActive()) {
            return false;
        }

        if (consumedActions.get(action) == hxd.Timer.frameCount) {
            return false;
        }

        var baseAction = mapAction(action);
        var actionBindings = controller.bindings.get(baseAction);
        if (actionBindings == null) {
            return false;
        }

        for (binding in actionBindings) {
            if (binding.isPressed(controller.pad)) {
                return true;
            }
        }

        return false;
    }

    public function consumePressed(action:TAccess):Bool {
        if (peekPressed(action)) {
            consumedActions.set(action, hxd.Timer.frameCount);
            return true;
        }
        return false;
    }

    public function peekReleased(action:TAccess):Bool {
        if (!isActive()) {
            return false;
        }

        if (consumedActions.get(action) == hxd.Timer.frameCount) {
            return false;
        }

        var baseAction = mapAction(action);
        var actionBindings = controller.bindings.get(baseAction);
        if (actionBindings == null) {
            return false;
        }

        for (binding in actionBindings) {
            if (binding.isReleased(controller.pad)) {
                return true;
            }
        }

        return false;
    }

    public function consumeReleased(action:TAccess):Bool {
        if (peekReleased(action)) {
            consumedActions.set(action, hxd.Timer.frameCount);
            return true;
        }
        return false;
    }

    public inline function initHeldState(action:TAccess):Void {
        holdTimeS.remove(action);
    }

    public inline function updateHeldState(action:TAccess):Void {
        var down = isDown(action);
        if (!down) {
            holdTimeS.remove(action);
            return;
        }

        if (!holdTimeS.exists(action)) {
            holdTimeS.set(action, haxe.Timer.stamp());
        }
    }

    public inline function isHeld(action:TAccess, seconds:Float):Bool {
        updateHeldState(action);
        if (!isDown(action)) {
            return false;
        }

        var started = holdTimeS.get(action);
        if (started != null && started >= 0 && getRawHoldTimeS(action) >= seconds) {
            holdTimeS.set(action, -1);
            return true;
        }

        return false;
    }

    inline function getRawHoldTimeS(action:TAccess):Float {
        if (!holdTimeS.exists(action)) {
            return 0.0;
        }

        var started = holdTimeS.get(action);
        if (started == null || started < 0) {
            return 0.0;
        }

        return haxe.Timer.stamp() - started;
    }

    public inline function getHoldRatio(action:TAccess, seconds:Float):Float {
        updateHeldState(action);
        if (!holdTimeS.exists(action)) {
            return 0.0;
        }

        var started = holdTimeS.get(action);
        if (started == null) {
            return 0.0;
        }

        if (started < 0) {
            return 1.0;
        }

        return clamp(getRawHoldTimeS(action) / seconds, 0.0, 1.0);
    }

    public inline function getHoldTimeS(action:TAccess):Float {
        updateHeldState(action);
        return getRawHoldTimeS(action);
    }

    public inline function peekPressedAutoFire(action:TAccess, firstDelayS:Float = 0.28, repeatDelayS:Float = 0.07):Bool {
        if (consumedActions.get(action) == hxd.Timer.frameCount) {
            return false;
        }

        if (!isDown(action)) {
            return false;
        }

        var now = haxe.Timer.stamp();
        var next = autoFireNextS.get(action);
        if (next == null || now >= next) {
            return true;
        }

        return false;
    }

    public inline function consumePressedAutoFire(action:TAccess, firstDelayS:Float = 0.28, repeatDelayS:Float = 0.07):Bool {
        if (consumedActions.get(action) == hxd.Timer.frameCount) {
            return false;
        }

        if (!isDown(action)) {
            autoFireNextS.set(action, 0.0);
            autoFireFirstDone.remove(action);
            return false;
        }

        var now = haxe.Timer.stamp();
        var next = autoFireNextS.get(action);
        if (next == null || now >= next) {
            var delay = autoFireFirstDone.exists(action) ? repeatDelayS : firstDelayS;
            autoFireNextS.set(action, now + delay);
            autoFireFirstDone.set(action, true);
            consumedActions.set(action, hxd.Timer.frameCount);
            return true;
        }

        return false;
    }

    public inline function isNegative(action:TAccess, threshold:Float = 0.0):Bool {
        return getAnalogValue(action) < -Math.abs(threshold);
    }

    public inline function isPositive(action:TAccess, threshold:Float = 0.0):Bool {
        return getAnalogValue(action) > Math.abs(threshold);
    }

    public inline function isKeyboardDown(key:Int):Bool {
        return isActive() && Key.isDown(key);
    }

    public inline function isKeyboardPressed(key:Int):Bool {
        return isActive() && Key.isPressed(key);
    }

    public inline function isPadDown(buttonId:Int):Bool {
        return isActive() && controller.pad != null && controller.pad.isDown(buttonId);
    }

    public inline function isPadPressed(buttonId:Int):Bool {
        return isActive() && controller.pad != null && controller.pad.isPressed(buttonId);
    }

    public inline function getPadLeftStickDist():Float {
        if (!isActive() || controller.pad == null) {
            return 0.0;
        }
        return getDistance(0, 0, controller.pad.xAxis, controller.pad.yAxis);
    }

    public inline function getPadRightStickDist():Float {
        if (!isActive() || controller.pad == null) {
            return 0.0;
        }
        return getDistance(0, 0, controller.pad.rxAxis, controller.pad.ryAxis);
    }

    public inline function rumble(strength:Float, seconds:Float):Void {
        if (!destroyed) {
            controller.rumble(strength, seconds);
        }
    }

    public dynamic function lockCondition():Bool {
        return false;
    }

    public inline function lock(durationSeconds:Float = 999999.0):Void {
        lockedUntilS = haxe.Timer.stamp() + durationSeconds;
    }

    public inline function unlock():Void {
        lockedUntilS = -1.0;
    }

    public inline function takeExclusivity():Void {
        if (!destroyed) {
            controller.makeExclusive(this);
        }
    }

    public inline function releaseExclusivity():Void {
        if (!destroyed) {
            controller.releaseExclusivity();
        }
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : value > max ? max : value;
    }

    static inline function getDistance(x1:Float, y1:Float, x2:Float, y2:Float):Float {
        var dx = x2 - x1;
        var dy = y2 - y1;
        return Math.sqrt(dx * dx + dy * dy);
    }
}
