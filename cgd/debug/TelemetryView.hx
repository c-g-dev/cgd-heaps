package cgd.debug;

class TelemetryView extends h2d.Object {

    public var refreshInterval:Float = 1.0;
    public var panelPadding:Float = 6.0;

    var scene:h2d.Scene;
    var background:h2d.Graphics;
    var label:h2d.Text;
    var elapsed:Float = 0.0;

    public function new(scene:h2d.Scene, ?parent:h2d.Object, ?font:h2d.Font) {
        super(parent == null ? scene : parent);
        this.scene = scene;

        x = 8;
        y = 8;

        background = new h2d.Graphics(this);
        label = new h2d.Text(font == null ? hxd.res.DefaultFont.get() : font, this);
        label.textColor = 0xFFFFFF;
        label.dropShadow = {
            dx: 1,
            dy: 1,
            color: 0x000000,
            alpha: 0.8
        };

        refresh();
    }

    override function onUpdate(dt:Float):Void {
        elapsed += dt;
        if(elapsed < refreshInterval) {
            return;
        }

        while(elapsed >= refreshInterval) {
            elapsed -= refreshInterval;
        }
        refresh();
    }

    public function refresh():Void {
        label.text = [
            'FPS: ${formatFps(hxd.Timer.fps())}',
            'Objects: ${countTreeObjects(scene)}',
            'Memory: ${formatMemory()}'
        ].join("\n");

        drawBackground();
    }

    function drawBackground():Void {
        label.x = 0;
        label.y = 0;

        var bounds = label.getBounds(this);
        label.x = panelPadding - bounds.xMin;
        label.y = panelPadding - bounds.yMin;
        bounds = label.getBounds(this);

        background.clear();
        background.lineStyle(1, 0xFFFFFF, 0.18);
        background.beginFill(0x000000, 0.7);
        background.drawRect(
            0,
            0,
            bounds.xMax + panelPadding,
            bounds.yMax + panelPadding
        );
        background.endFill();
    }

    static function countTreeObjects(root:h2d.Object):Int {
        var count = 1;
        for(i in 0...root.numChildren) {
            count += countTreeObjects(root.getChildAt(i));
        }
        return count;
    }

    static function formatFps(value:Float):String {
        return Std.string(Math.round(value));
    }

    static function formatMemory():String {
        var bytes = getMemoryBytes();
        if(bytes == null) {
            return "N/A";
        }
        return formatBytes(bytes);
    }

    static function formatBytes(value:Float):String {
        var units = ["B", "KB", "MB", "GB", "TB"];
        var unitIndex = 0;
        var size = value;

        while(size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            unitIndex++;
        }

        var rounded = Math.round(size * 10) / 10;
        if(unitIndex == 0) {
            return '${Std.int(rounded)} ${units[unitIndex]}';
        }
        return '${rounded} ${units[unitIndex]}';
    }

    static function getMemoryBytes():Null<Float> {
        #if hl
        return hl.Gc.stats().currentMemory;
        #elseif js
        return js.Syntax.code("performance.memory ? performance.memory.usedJSHeapSize : null");
        #else
        return null;
        #end
    }

}
