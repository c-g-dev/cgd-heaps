package cgd.debug;

import hxd.App;
import hxd.Event.EventKind;

class KeyTool {
    public function new() {}

    public function on(key: Int, callback: Void->Void):Void {
        App.current().s2d.addEventListener((e) -> {
            trace(e);
            if (e.kind == EventKind.EKeyUp && e.keyCode == key) {
                callback();
            }
        });
    }
}