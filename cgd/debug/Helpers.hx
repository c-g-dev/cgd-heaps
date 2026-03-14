package cgd.debug;

import hxd.App;


class KeyTool {
    public function new() {}

    public function on(key: Int, callback: Void->Void):Void {
        App.current().s2d.addEventListener((e) -> {
            if (e.kind == KeyEvent.KeyUp && e.keyCode == key) {
                callback();
            }
        })
    }
}