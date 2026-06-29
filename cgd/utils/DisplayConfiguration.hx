package cgd.utils;

#if !macro
import h2d.Object;
import haxe.Json;
import hxd.res.Loader;

#if cgd_debug
import cgd.debug.DisplayConfigurationDebug;
#end
#end

#if macro
import haxe.macro.Expr;
#end

@:allow(cgd.debug.DisplayConfigurationDebug)
class DisplayConfiguration {

	public static var CONFIG_SUBDIR = "display_configs";

	#if !macro
	static var bindings = new Map<String, DisplayConfigurationBinding>();
	#end

	#if macro
	macro public static function displayWithConfiguration(key:Expr, obj:Expr) {
		return macro cgd.utils.DisplayConfiguration.bind($key, $obj, hxd.Res.loader);
	}
	#end

	#if !macro
	public static function preload(loader:Loader):Void {
		DisplayConfigurationCache.preload(loader);
	}

	public static function canPersist(loader:Loader):Bool {
		#if cgd_debug
		#if ((sys || nodejs) && !usesys)
		return Std.isOfType(loader.fs, hxd.fs.LocalFileSystem);
		#else
		return false;
		#end
		#else
		return false;
		#end
	}

	public static function bind(key:String, obj:Object, loader:Loader):Void {
		if (bindings.exists(key)) {
			throw 'DisplayConfiguration: key already bound: $key';
		}

		DisplayConfigurationCache.preload(loader);

		var resPath = CONFIG_SUBDIR + "/" + key + ".json";
		var binding:DisplayConfigurationBinding = {
			key: key,
			obj: obj,
			loader: loader,
			resPath: resPath,
			lastApplied: null,
			saveDebounce: 0,
			watchResource: null
		};
		bindings.set(key, binding);

		var data = DisplayConfigurationCache.get(loader, key);
		if (data == null) {
			data = DisplayConfigurationCache.loadFromResource(loader, key, resPath);
		}

		if (data != null) {
			applyBinding(binding, data);
		}
		#if cgd_debug
		else if (canPersist(loader)) {
			var initial = TransformUtils.serialize(obj);
			writeBinding(binding, initial);
		}

		if (canPersist(loader)) {
			DisplayConfigurationDebug.enable(binding);
		}
		#end
	}

	public static function unbind(key:String):Void {
		var binding = bindings.get(key);
		if (binding == null) {
			return;
		}
		#if cgd_debug
		DisplayConfigurationDebug.disable(binding);
		#end
		bindings.remove(key);
	}

	#if cgd_debug
	public static function getKeys():Array<String> {
		var keys = [];
		for (key in bindings.keys()) {
			var binding = bindings.get(key);
			if (binding != null && canPersist(binding.loader)) {
				keys.push(key);
			}
		}
		keys.sort(function(a, b) {
			return Reflect.compare(a, b);
		});
		return keys;
	}

	public static function isEditingEnabled():Bool {
		for (binding in bindings) {
			if (canPersist(binding.loader)) {
				return true;
			}
		}
		return false;
	}

	public static function startEditing(key:String):Void {
		DisplayConfigurationDebug.startEditing(key);
	}

	public static function stopEditing():Void {
		DisplayConfigurationDebug.stopEditing();
	}

	public static function getEditingKey():Null<String> {
		return DisplayConfigurationDebug.getEditingKey();
	}
	#end

	static function applyBinding(binding:DisplayConfigurationBinding, data:Dynamic):Void {
		TransformUtils.apply(binding.obj, data);
		binding.lastApplied = data;
	}

	static function getBinding(key:String):Null<DisplayConfigurationBinding> {
		return bindings.get(key);
	}

	static function getBindings():Map<String, DisplayConfigurationBinding> {
		return bindings;
	}

	static function writeBinding(binding:DisplayConfigurationBinding, data:Dynamic):Void {
		DisplayConfigurationCache.set(binding.loader, binding.key, data);
		binding.lastApplied = data;
		if (canPersist(binding.loader)) {
			writeToDisk(binding, data);
		}
	}

	static function reloadBindingFromDisk(binding:DisplayConfigurationBinding):Void {
		var data = DisplayConfigurationCache.reloadFromResource(binding.loader, binding.key, binding.resPath);
		if (data != null && binding.obj.parent != null) {
			applyBinding(binding, data);
		}
	}

	static function writeToDisk(binding:DisplayConfigurationBinding, data:Dynamic):Void {
		#if ((sys || nodejs) && !usesys)
		var fs = Std.downcast(binding.loader.fs, hxd.fs.LocalFileSystem);
		if (fs == null) {
			return;
		}

		var file = binding.resPath;
		if (!haxe.io.Path.isAbsolute(file)) {
			file = fs.baseDir + file;
		}

		var dir = haxe.io.Path.directory(file);
		if (dir != "" && !sys.FileSystem.exists(dir)) {
			sys.FileSystem.createDirectory(dir);
		}

		sys.io.File.saveContent(file, Json.stringify(data, "\t"));
		#end
	}
	#end
}
