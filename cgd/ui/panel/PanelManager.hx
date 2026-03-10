package cgd.ui.panel;

import heaps.coroutine.Future;

private typedef PanelStackEntry = {
    var panel:Panel;
    var overlay:Null<h2d.Bitmap>;
    var closeOnPop:Bool;
}

class PanelManager extends h2d.Object {

    var entries:Array<PanelStackEntry>;
    var lastWindowWidth:Int;
    var lastWindowHeight:Int;

    public function new(?parent:h2d.Object) {
        super(parent);
        entries = [];
        lastWindowWidth = -1;
        lastWindowHeight = -1;
    }

    public function push(panel:Panel, ?modal:Bool = true, ?closeOnPop:Bool = true, ?overlayColor:Int = 0x000000, ?overlayAlpha:Float = 0.65):Panel {
        if( panel == null ) throw "PanelManager.push requires a non-null panel.";

        var overlay = modal ? new h2d.Bitmap(h2d.Tile.fromColor(overlayColor, 1, 1, overlayAlpha), this) : null;
        if( overlay != null )
            resizeOverlay(overlay);

        addChild(panel);
        entries.push({
            panel: panel,
            overlay: overlay,
            closeOnPop: closeOnPop,
        });

        return panel;
    }

    public function pop():Future {
        if( entries.length == 0 ) return Future.immediate();

        var entry = entries.pop();
        if( entry.closeOnPop ) {
            var completion = new Future();
            entry.panel.close().then(function(_) {
                if( entry.overlay != null )
                    entry.overlay.remove();
                if( entry.panel.parent == this )
                    entry.panel.remove();
                completion.resolve(null);
            });
            return completion;
        }

        if( entry.overlay != null )
            entry.overlay.remove();
        if( entry.panel.parent == this )
            entry.panel.remove();
        return Future.immediate();
    }

    public function removePanel(panel:Panel):Bool {
        if( panel == null ) return false;

        for( i in 0...entries.length ) {
            if( entries[i].panel == panel ) {
                var entry = entries.splice(i, 1)[0];
                if( entry.overlay != null )
                    entry.overlay.remove();
                if( panel.parent == this )
                    panel.remove();
                return true;
            }
        }

        return false;
    }

    public function getTopPanel():Null<Panel> {
        if( entries.length == 0 ) return null;
        return entries[entries.length - 1].panel;
    }

    override function onUpdate(dt:Float):Void {
        super.onUpdate(dt);

        for( i in 0...entries.length ) {
            var reverseIndex = entries.length - 1 - i;
            var entry = entries[reverseIndex];
            if( entry.panel.parent == this ) continue;

            if( entry.overlay != null )
                entry.overlay.remove();
            entries.splice(reverseIndex, 1);
        }

        var window = hxd.Window.getInstance();
        if( window.width == lastWindowWidth && window.height == lastWindowHeight ) return;

        lastWindowWidth = window.width;
        lastWindowHeight = window.height;

        for( entry in entries ) {
            if( entry.overlay != null )
                resizeOverlay(entry.overlay);
        }
    }

    function resizeOverlay(overlay:h2d.Bitmap):Void {
        var window = hxd.Window.getInstance();
        overlay.width = window.width;
        overlay.height = window.height;
    }

}
