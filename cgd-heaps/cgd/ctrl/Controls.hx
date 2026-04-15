package cgd.ctrl;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class Controls {
    static var globalController:Null<Controller<Int>>;
    static var mappers:Map<String, Int->Int> = new Map();

    /**
     * Registers a typed Controller as the global input authority.
     * Call this once during app init, after binding all physical keys/buttons.
     *
     * Example:
     *   var ctrl = Controller.createFromAbstractEnum(GameActions);
     *   ctrl.bindKeyboard(GameActions.Confirm, Key.SPACE);
     *   Controls.setGlobal(ctrl);
     */
    public static function setGlobal<TBase:Int>(ctrl:Controller<TBase>):Void {
        globalController = cast ctrl;
    }

    /**
     * Registers a translation function for a specific component class.
     * The mapper receives a value from the component's local action enum (as Int)
     * and must return the corresponding value from the app's primary action schema.
     *
     * Example:
     *   Controls.registerMapper(UIDropdown, function(action:MenuActions) {
     *       return switch(action) {
     *           case Up:     GameActions.MoveUp;
     *           case Down:   GameActions.MoveDown;
     *           case Select: GameActions.Confirm;
     *       }
     *   });
     */
    public static function registerMapper<TClass>(cls:Class<TClass>, mapper:Int->Int):Void {
        mappers.set(Type.getClassName(cls), mapper);
    }

    /**
     * Returns a ControllerAccess for the calling class.
     * This is a macro: the calling class name is injected at compile time, so
     * no runtime reflection or string literals are needed in components.
     *
     * If a mapper was registered for this class, actions will be translated
     * through it before querying the root controller's bindings.
     * If no mapper is registered, actions are queried as raw Int values.
     *
     * Example (component):
     *   var controls:ControllerAccess<MenuActions> = Controls.get();
     */
    macro public static function get():Expr {
        var localClass = Context.getLocalClass();
        if (localClass == null) {
            Context.error("Controls.get() must be called from within a class.", Context.currentPos());
        }
        var className = localClass.toString();
        return macro cgd.ctrl.Controls._getForClass($v{className});
    }

    @:noCompletion
    public static function _getForClass<TAccess:Int>(className:String):ControllerAccess<TAccess, Int> {
        if (globalController == null) {
            throw "Controls.setGlobal() must be called before any component calls Controls.get().";
        }
        var mapper:Null<TAccess->Int> = cast mappers.get(className);
        return new ControllerAccess<TAccess, Int>(globalController, mapper);
    }
}
