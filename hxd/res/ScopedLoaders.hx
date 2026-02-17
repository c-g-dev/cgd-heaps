package hxd.res;

class ScopedLoaders {

	static var loaders : Map<String, Loader> = new Map();
	static var defaultScopeId : String;

	public static function clear() {
		loaders = new Map();
		defaultScopeId = null;
	}

	public static function setScopeLoader( scopeId : String, loader : Loader ) {
		loaders.set(scopeId, loader);
		if( defaultScopeId == null )
			defaultScopeId = scopeId;
	}

	public static function setDefaultScope( scopeId : String ) {
		defaultScopeId = scopeId;
	}

	public static function get( scopeId : String ) : Loader {
		var l = loaders.get(scopeId);
		if( l == null )
			throw "Scoped resource loader not initialized for scope " + scopeId + " (call hxd.Res.initXXX() first)";
		return l;
	}

	public static function getDefaultLoader() : Loader {
		if( defaultScopeId == null )
			throw "Scoped resource default loader not initialized (call hxd.Res.initXXX() first)";
		return get(defaultScopeId);
	}

}
