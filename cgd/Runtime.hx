package cgd;

class Runtime {

    private static var callbackRegistry:Map<String,Array<Void->Void>>;

    public static function afterResourcesLoaded(callback:Void->Void):Void {
        initCallbackRegistry("resources-loaded");
        callbackRegistry.get("resources-loaded").push(callback);
    }

    private static function initCallbackRegistry(tag:String):Void {
        if( callbackRegistry == null ) {
            callbackRegistry = new Map<String,Array<Void->Void>>();
        }
        var callbacks = callbackRegistry.get(tag);
        if( callbacks == null ) {
            callbacks = [];
            callbackRegistry.set(tag, callbacks);
        }
    }

    private static function notifyResourcesLoaded():Void {
        trace('notifying resources loaded');
        triggerCallback("resources-loaded");
    }

    private static function triggerCallback(tag:String):Void {
        trace('triggering callback for tag: ${tag}');
        initCallbackRegistry("resources-loaded");
        var callbacks = callbackRegistry.get(tag);
        if( callbacks == null ) return;
        for(callback in callbacks) {
            callback();
        }
    }

}