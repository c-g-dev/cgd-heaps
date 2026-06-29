#if cgd_debug
package cgd.debug;

import cgd.utils.DisplayConfiguration;
import cgd.utils.DisplayConfigurationBinding;
import cgd.utils.TransformUtils;
import hxd.Key;

class DisplayConfigurationDebug {
	static inline var SAVE_DEBOUNCE_SEC = 0.3;

	static var editingKey:Null<String> = null;
	static var keysInstalled = false;

	public static function enable(binding:DisplayConfigurationBinding):Void {
		if (!DisplayConfiguration.canPersist(binding.loader)) {
			return;
		}

		if (binding.watchResource == null && binding.loader.exists(binding.resPath)) {
			binding.watchResource = binding.loader.load(binding.resPath);
		}

		if (binding.watchResource != null) {
			binding.watchResource.entry.watch(function() {
				if (binding.obj.parent == null) {
					DisplayConfiguration.unbind(binding.key);
					return;
				}
				DisplayConfiguration.reloadBindingFromDisk(binding);
			});
		}

		installKeyHandlers();
	}

	public static function disable(binding:DisplayConfigurationBinding):Void {
		if (binding.watchResource != null) {
			binding.watchResource.entry.watch(null);
			binding.watchResource = null;
		}
		if (editingKey == binding.key) {
			stopEditing();
		}
	}

	public static function update():Void {
		if (!DisplayConfiguration.isEditingEnabled()) {
			return;
		}

		var dt = hxd.Timer.dt;
		var toRemove:Array<String> = [];

		for (binding in DisplayConfiguration.getBindings()) {
			if (!DisplayConfiguration.canPersist(binding.loader)) {
				continue;
			}

			if (binding.obj.parent == null) {
				toRemove.push(binding.key);
				continue;
			}

			var current = TransformUtils.serialize(binding.obj);
			if (!TransformUtils.fieldsEqual(current, binding.lastApplied)) {
				binding.saveDebounce = SAVE_DEBOUNCE_SEC;
			}

			if (binding.saveDebounce > 0) {
				binding.saveDebounce -= dt;
				if (binding.saveDebounce <= 0) {
					DisplayConfiguration.writeBinding(binding, current);
				}
			}
		}

		for (key in toRemove) {
			DisplayConfiguration.unbind(key);
		}
	}

	public static function startEditing(key:String):Void {
		var binding = DisplayConfiguration.getBinding(key);
		if (binding == null) {
			throw 'DisplayConfiguration: no binding for key: $key';
		}
		if (!DisplayConfiguration.canPersist(binding.loader)) {
			throw 'DisplayConfiguration: editing is not available without filesystem access';
		}
		editingKey = key;
		LayoutEditor.setTarget(binding.obj);
	}

	public static function stopEditing():Void {
		editingKey = null;
		LayoutEditor.setTarget(null);
	}

	public static function getEditingKey():Null<String> {
		return editingKey;
	}

	static function installKeyHandlers():Void {
		if (keysInstalled) {
			return;
		}
		keysInstalled = true;

		var app = hxd.App.current();
		if (app == null) {
			return;
		}

		app.s2d.onKeyUp(Key.ESCAPE, function() {
			if (editingKey != null) {
				stopEditing();
			}
		});
	}
}
#end
