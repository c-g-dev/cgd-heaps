package cgd.utils;

import haxe.Json;
import hxd.res.Loader;

class DisplayConfigurationCache {

	static var dataByLoader = new Map<Loader, Map<String, Dynamic>>();
	static var preloadedLoaders = new Map<Loader, Bool>();

	public static function preload(loader:Loader, ?subdir:String):Void {
		if (preloadedLoaders.exists(loader)) {
			return;
		}
		preloadedLoaders.set(loader, true);

		var dir = subdir == null ? DisplayConfiguration.CONFIG_SUBDIR : subdir;
		if (!loader.exists(dir)) {
			return;
		}

		for (res in loader.dir(dir)) {
			var name = res.entry.name;
			if (!StringTools.endsWith(name, ".json")) {
				continue;
			}
			var key = name.substr(0, name.length - 5);
			var resPath = dir + "/" + name;
			loadFromResource(loader, key, resPath);
		}
	}

	public static function get(loader:Loader, key:String):Null<Dynamic> {
		var cache = getLoaderCache(loader);
		return cache.get(key);
	}

	public static function set(loader:Loader, key:String, data:Dynamic):Void {
		getLoaderCache(loader).set(key, data);
	}

	public static function loadFromResource(loader:Loader, key:String, resPath:String):Null<Dynamic> {
		if (!loader.exists(resPath)) {
			return null;
		}
		var data = Json.parse(loader.load(resPath).toText());
		set(loader, key, data);
		return data;
	}

	public static function reloadFromResource(loader:Loader, key:String, resPath:String):Null<Dynamic> {
		if (!loader.exists(resPath)) {
			return null;
		}
		var data = Json.parse(loader.load(resPath).toText());
		set(loader, key, data);
		return data;
	}

	static function getLoaderCache(loader:Loader):Map<String, Dynamic> {
		var cache = dataByLoader.get(loader);
		if (cache == null) {
			cache = new Map();
			dataByLoader.set(loader, cache);
		}
		return cache;
	}
}
