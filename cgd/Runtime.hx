package cgd;

import cgd.utils.uri.RuntimeLocatorProtocol;
import cgd.utils.uri.RuntimeURI;

class Runtime {

    private static var DEFAULT_PROTOCOL:String = "myapp";
    private static var protocolResolverRegistry:Map<RuntimeURIProtocol,RuntimeLocatorProtocol>;
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

    public static function locate(uri: String): Dynamic {
        var runtimeURI = new RuntimeURI(uri);
        var resolver = protocolResolverRegistry.get(runtimeURI.protocol);
        if( resolver == null ) {
            throw 'No resolver found for protocol: ${runtimeURI.protocol}';
        }
        return resolver.locate(uri);
    }



    public static function addProtocolResolver(protocol: RuntimeURIProtocol, resolver: RuntimeLocatorProtocol): Void {
        if( protocolResolverRegistry == null ) {
            protocolResolverRegistry = new Map<RuntimeURIProtocol,RuntimeLocatorProtocol>();
        }
        protocolResolverRegistry.set(protocol, resolver);
    }

    public static function inject(uri: String, value: Dynamic): Void {
        var runtimeURI = new RuntimeURI(uri);
        var resolver = protocolResolverRegistry.get(runtimeURI.protocol);
        if( resolver == null ) {
            throw 'No resolver found for protocol: ${runtimeURI.protocol}';
        }
        resolver.inject(uri, value);
    }

}