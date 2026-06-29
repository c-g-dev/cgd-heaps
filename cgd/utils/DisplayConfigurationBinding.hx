package cgd.utils;

import h2d.Object;
import hxd.res.Loader;

typedef DisplayConfigurationBinding = {
	var key:String;
	var obj:Object;
	var loader:Loader;
	var resPath:String;
	var lastApplied:Dynamic;
	var saveDebounce:Float;
	var watchResource:hxd.res.Any;
}
