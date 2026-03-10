package cgd.ui.panel;

import cgd.ui.panel.PanelStyles.PanelHAlign;
import cgd.ui.panel.PanelStyles.PanelSizing;
import cgd.ui.panel.PanelStyles.PanelStyle;
import heaps.coroutine.Future;

private typedef PanelSlotMetrics = {
    var hasContent:Bool;
    var width:Float;
    var height:Float;
    var xMin:Float;
    var yMin:Float;
}

class Panel extends h2d.Object {

    public var headerRoot(default, null):h2d.Object;
    public var contentRoot(default, null):h2d.Object;
    public var footerRoot(default, null):h2d.Object;
    public var width(default, null):Float;
    public var height(default, null):Float;
    public var innerWidth(default, null):Float;
    public var innerHeight(default, null):Float;

    var style:PanelStyle;
    var backgroundBitmap:Null<h2d.Bitmap>;
    var backgroundGrid:Null<h2d.ScaleGrid>;
    var properties:Map<String, Dynamic>;
    var listeners:Map<String, Array<Dynamic -> Void>>;
    var plugins:Array<PanelPlugin>;

    public function new(styleName:String, ?parent:h2d.Object) {
        super(parent);
        style = PanelStyles.get(styleName);
        properties = [];
        listeners = [];
        plugins = [];
        width = 0;
        height = 0;
        innerWidth = 0;
        innerHeight = 0;
        backgroundBitmap = null;
        backgroundGrid = null;
        headerRoot = new h2d.Object(this);
        contentRoot = new h2d.Object(this);
        footerRoot = new h2d.Object(this);
        buildFromStyle();
    }

    function buildFromStyle():Void {
        createBackground();

        for( factory in style.pluginFactories ) {
            var plugin = factory(this);
            if( plugin != null ) {
                plugins.push(plugin);
                plugin.onAttach();
            }
        }

        for( callback in style.onInitCallbacks )
            callback(this);

        relayout();
    }

    function createBackground():Void {
        if( style.background == null ) return;

        if( style.useScaleGrid ) {
            backgroundGrid = new h2d.ScaleGrid(
                style.background,
                style.borderLeft,
                style.borderTop,
                style.borderRight,
                style.borderBottom,
                this
            );
            backgroundGrid.tileBorders = style.tileBorders;
            backgroundGrid.tileCenter = style.tileCenter;
            backgroundGrid.ignoreScale = style.ignoreScale;
            backgroundGrid.borderScale = style.borderScale;
        } else {
            backgroundBitmap = new h2d.Bitmap(style.background, this);
        }
    }

    public function setHeader(header:Null<h2d.Object>):Void {
        replaceSlotContent(headerRoot, header);
        for( plugin in plugins ) plugin.onHeaderChanged(header);
        emit("headerChanged", header);
        relayout();
    }

    public function setContent(content:Null<h2d.Object>):Void {
        replaceSlotContent(contentRoot, content);
        for( plugin in plugins ) plugin.onContentChanged(content);
        emit("contentChanged", content);
        relayout();
    }

    public function setFooter(footer:Null<h2d.Object>):Void {
        replaceSlotContent(footerRoot, footer);
        for( plugin in plugins ) plugin.onFooterChanged(footer);
        emit("footerChanged", footer);
        relayout();
    }

    public function getHeader():Null<h2d.Object> {
        return headerRoot.numChildren > 0 ? headerRoot.getChildAt(0) : null;
    }

    public function getContent():Null<h2d.Object> {
        return contentRoot.numChildren > 0 ? contentRoot.getChildAt(0) : null;
    }

    public function getFooter():Null<h2d.Object> {
        return footerRoot.numChildren > 0 ? footerRoot.getChildAt(0) : null;
    }

    public function relayout():Void {
        var header = measureSlot(headerRoot);
        var content = measureSlot(contentRoot);
        var footer = measureSlot(footerRoot);

        var stackedHeight = header.height + content.height + footer.height;
        var visibleSlots = 0;
        if( header.hasContent ) visibleSlots++;
        if( content.hasContent ) visibleSlots++;
        if( footer.hasContent ) visibleSlots++;
        if( visibleSlots > 1 )
            stackedHeight += style.slotGap * (visibleSlots - 1);

        var measuredInnerWidth = Math.max(header.width, Math.max(content.width, footer.width));
        var measuredWidth = style.paddingLeft + measuredInnerWidth + style.paddingRight;
        var measuredHeight = style.paddingTop + stackedHeight + style.paddingBottom;

        switch( style.sizing ) {
        case Fixed(fixedWidth, fixedHeight):
            width = fixedWidth;
            height = fixedHeight;
        case FitContent:
            width = measuredWidth;
            height = measuredHeight;
        case FitContentMin(minWidth, minHeight):
            width = Math.max(minWidth, measuredWidth);
            height = Math.max(minHeight, measuredHeight);
        }

        innerWidth = Math.max(0, width - style.paddingLeft - style.paddingRight);
        innerHeight = Math.max(0, height - style.paddingTop - style.paddingBottom);

        updateBackgroundSize();

        var currentY = style.paddingTop;
        layoutSlot(headerRoot, header, currentY);
        if( header.hasContent ) currentY += header.height;
        if( header.hasContent && (content.hasContent || footer.hasContent) ) currentY += style.slotGap;

        layoutSlot(contentRoot, content, currentY);
        if( content.hasContent ) currentY += content.height;
        if( content.hasContent && footer.hasContent ) currentY += style.slotGap;

        layoutSlot(footerRoot, footer, currentY);

        for( plugin in plugins )
            plugin.onRelayout(width, height);

        emit("relayout", {
            width: width,
            height: height,
            innerWidth: innerWidth,
            innerHeight: innerHeight,
        });
    }

    public dynamic function open():Future {
        alpha = 1;
        notifyOpened();
        return Future.immediate();
    }

    public dynamic function isOpen():Bool {
        return alpha > 0;
    }

    public dynamic function isClosed():Bool {
        return !isOpen();
    }

    public dynamic function close():Future {
        alpha = 0;
        notifyClosed();
        remove();
        return Future.immediate();
    }

    public function set(key:String, value:Dynamic):Void {
        if( key == null || key == "" ) throw "Panel.set requires a non-empty key.";
        var oldValue = properties.get(key);
        properties.set(key, value);
        for( plugin in plugins ) plugin.onPropertyChanged(key, value);
        emit("propertyChanged", { key: key, value: value, oldValue: oldValue });
    }

    public function get(key:String):Dynamic {
        if( key == null ) return null;
        return properties.get(key);
    }

    public function on(event:String, callback:Dynamic -> Void):Void {
        if( event == null || event == "" || callback == null ) return;
        if( !listeners.exists(event) ) listeners.set(event, []);
        listeners.get(event).push(callback);
    }

    public function off(event:String, ?callback:Dynamic -> Void):Void {
        if( event == null ) return;
        if( callback == null ) {
            listeners.remove(event);
            return;
        }
        var list = listeners.get(event);
        if( list == null ) return;
        list.remove(callback);
    }

    public function emit(event:String, data:Dynamic):Void {
        if( event == null ) return;
        var list = listeners.get(event);
        if( list == null ) return;
        var snapshot = [for( cb in list ) cb];
        for( cb in snapshot ) cb(data);
    }

    public function getContentBounds(?relativeTo:h2d.Object):h2d.col.Bounds {
        var contentBounds = new h2d.col.Bounds();
        contentBounds.empty();
        contentBounds.addBounds(headerRoot.getBounds(relativeTo == null ? this : relativeTo));
        contentBounds.addBounds(contentRoot.getBounds(relativeTo == null ? this : relativeTo));
        contentBounds.addBounds(footerRoot.getBounds(relativeTo == null ? this : relativeTo));
        return contentBounds;
    }

    override function onRemove():Void {
        super.onRemove();
        for( plugin in plugins ) plugin.onDetach();
    }

    function replaceSlotContent(root:h2d.Object, child:Null<h2d.Object>):Void {
        root.removeChildren();
        if( child != null )
            root.addChild(child);
    }

    public function notifyOpened():Void {
        for( plugin in plugins ) plugin.onOpen();
        emit("opened", null);
    }

    public function notifyClosed():Void {
        for( plugin in plugins ) plugin.onClose();
        emit("closed", null);
    }

    function updateBackgroundSize():Void {
        if( backgroundBitmap != null ) {
            backgroundBitmap.width = width;
            backgroundBitmap.height = height;
        }

        if( backgroundGrid != null ) {
            if( width < style.borderLeft + style.borderRight )
                throw "Panel width is smaller than the configured scale-grid borders.";
            if( height < style.borderTop + style.borderBottom )
                throw "Panel height is smaller than the configured scale-grid borders.";
            backgroundGrid.width = width;
            backgroundGrid.height = height;
        }
    }

    function measureSlot(root:h2d.Object):PanelSlotMetrics {
        if( root.numChildren == 0 ) {
            return {
                hasContent: false,
                width: 0,
                height: 0,
                xMin: 0,
                yMin: 0,
            };
        }

        var bounds = root.getBounds(root);
        return {
            hasContent: true,
            width: bounds.width,
            height: bounds.height,
            xMin: bounds.xMin,
            yMin: bounds.yMin,
        };
    }

    function layoutSlot(root:h2d.Object, metrics:PanelSlotMetrics, y:Float):Void {
        if( !metrics.hasContent ) {
            root.x = style.paddingLeft;
            root.y = y;
            return;
        }

        root.x = resolveSlotX(metrics.width) - metrics.xMin;
        root.y = y - metrics.yMin;
    }

    function resolveSlotX(slotWidth:Float):Float {
        switch( style.slotAlign ) {
        case Left:
            return style.paddingLeft;
        case Center:
            return style.paddingLeft + ((innerWidth - slotWidth) * 0.5);
        case Right:
            return width - style.paddingRight - slotWidth;
        }
    }

}
