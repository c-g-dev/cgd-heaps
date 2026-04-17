package cgd.ctrl;

import hxd.Key;
#if macro
import haxe.macro.Expr;
#end

typedef ControllerPad = {
    public function isDown(buttonId:Int):Bool;
    public function isPressed(buttonId:Int):Bool;
    public function isReleased(buttonId:Int):Bool;
    public function rumble(strength:Float, seconds:Float):Void;
    var xAxis:Float;
    var yAxis:Float;
    var rxAxis:Float;
    var ryAxis:Float;
}

class Controller<TBase:Int = Int> {
    public var bindings(default, null):Map<TBase, Array<InputBinding<TBase>>> = new Map();
    public var pad(default, null):Null<ControllerPad>;

    public var disableRumble:Bool = false;
    public var rumbleMultiplicator:Float = 1.0;

    public var destroyed(default, null):Bool = false;
    public var exclusive(default, null):Null<IControllerAccess>;

    var accesses:Array<IControllerAccess> = [];

    public static macro function createFromAbstractEnum(actions:Expr, ?pad:Expr):Expr {
        return pad == null
            ? macro new cgd.ctrl.Controller()
            : macro new cgd.ctrl.Controller($pad);
    }

    public function new(?pad:ControllerPad) {
        this.pad = pad;
    }

    public function setPad(pad:ControllerPad):Void {
        this.pad = pad;
    }

    public function createAccess():ControllerAccess<TBase, TBase> {
        if (destroyed) {
            throw "Controller was destroyed.";
        }

        return new ControllerAccess<TBase, TBase>(this, null);
    }

    public function bindKeyboard(action:TBase, ?key:Null<Int>, ?alternatives:Array<Int>):Controller<TBase> {
        if (destroyed) {
            throw "Controller was destroyed.";
        }

        if (key != null) {
            addBinding(action, InputBinding.keyboard(key));
        }

        if (alternatives != null) {
            for (alt in alternatives) {
                addBinding(action, InputBinding.keyboard(alt));
            }
        }

        return this;
    }

    public function bindPadButton(action:TBase, buttonId:Int):Controller<TBase> {
        if (destroyed) {
            throw "Controller was destroyed.";
        }

        addBinding(action, InputBinding.padButton(buttonId));
        return this;
    }

    public function clearActionBindings(action:TBase):Void {
        bindings.remove(action);
    }

    public function clearAllBindings():Void {
        bindings = new Map();
    }

    public function makeExclusive(access:IControllerAccess):Void {
        if (destroyed) {
            return;
        }
        exclusive = access;
    }

    public function releaseExclusivity():Void {
        exclusive = null;
    }

    public function rumble(strength:Float, seconds:Float):Void {
        if (destroyed || disableRumble || pad == null) {
            return;
        }

        if (strength <= 0 || seconds <= 0) {
            return;
        }

        pad.rumble(strength * rumbleMultiplicator, seconds);
    }

    public function destroy():Void {
        if (destroyed) {
            return;
        }

        destroyed = true;
        exclusive = null;

        var existing = accesses.copy();
        for (access in existing) {
            access.dispose();
        }

        accesses = [];
        bindings = new Map();
        pad = null;
    }

    function addBinding(action:TBase, binding:InputBinding<TBase>):Void {
        var list = bindings.get(action);
        if (list == null) {
            list = [];
            bindings.set(action, list);
        }
        list.push(binding);
    }

    @:allow(cgd.ctrl.ControllerAccess)
    function registerAccess(access:IControllerAccess):Void {
        accesses.push(access);
    }

    @:allow(cgd.ctrl.ControllerAccess)
    function unregisterAccess(access:IControllerAccess):Void {
        accesses.remove(access);
        if (exclusive == access) {
            exclusive = null;
        }
    }
}


class InputBinding<T:Int> {
    var valueFn:Null<ControllerPad> -> Float;
    var downFn:Null<ControllerPad> -> Bool;
    var pressedFn:Null<ControllerPad> -> Bool;
    var releasedFn:Null<ControllerPad> -> Bool;

    public function new(
        valueFn:Null<ControllerPad> -> Float,
        downFn:Null<ControllerPad> -> Bool,
        pressedFn:Null<ControllerPad> -> Bool,
        releasedFn:Null<ControllerPad> -> Bool
    ) {
        this.valueFn = valueFn;
        this.downFn = downFn;
        this.pressedFn = pressedFn;
        this.releasedFn = releasedFn;
    }

    public inline function getValue(pad:Null<ControllerPad>):Float {
        return valueFn(pad);
    }

    public inline function isDown(pad:Null<ControllerPad>):Bool {
        return downFn(pad);
    }

    public inline function isPressed(pad:Null<ControllerPad>):Bool {
        return pressedFn(pad);
    }

    public inline function isReleased(pad:Null<ControllerPad>):Bool {
        return releasedFn(pad);
    }

    public static function keyboard<T:Int>(key:Int):InputBinding<T> {
        return new InputBinding<T>(
            function(_) return Key.isDown(key) ? 1.0 : 0.0,
            function(_) return Key.isDown(key),
            function(_) return Key.isPressed(key),
            function(_) return Key.isReleased(key)
        );
    }

    public static function padButton<T:Int>(buttonId:Int):InputBinding<T> {
        return new InputBinding<T>(
            function(pad) return pad != null && pad.isDown(buttonId) ? 1.0 : 0.0,
            function(pad) return pad != null && pad.isDown(buttonId),
            function(pad) return pad != null && pad.isPressed(buttonId),
            function(pad) return pad != null && pad.isReleased(buttonId)
        );
    }
}
