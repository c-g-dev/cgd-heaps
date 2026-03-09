package cgd.ui.multichoice;

import cgd.ui.Nav;
import cgd.ui.Nav.NavEvent;
import cgd.ui.multichoice.MultiChoiceStyles.BasicTextMultiChoiceItemRenderer;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceItemRenderer;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceLayout;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceOption;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceStyle;
import heaps.coroutine.Future;

private typedef MultiChoiceEntry = {
    var option:MultiChoiceOption;
    var root:h2d.Object;
    var renderer:MultiChoiceItemRenderer;
    var navigable:Bool;
}

class MultiChoiceBox extends h2d.Object {

    var style:MultiChoiceStyle;
    var background:Null<h2d.Bitmap>;
    var itemsRoot:h2d.Object;
    var nav:Nav;
    var properties:Map<String, Dynamic>;
    var listeners:Map<String, Array<Dynamic -> Void>>;
    var plugins:Array<MultiChoicePlugin>;
    var entries:Array<MultiChoiceEntry>;
    var entryByObject:Map<h2d.Object, MultiChoiceEntry>;
    var selectedIndex:Int;

    public function new(styleName:String, ?parent:h2d.Object) {
        super(parent);
        style = MultiChoiceStyles.get(styleName);
        properties = [];
        listeners = [];
        plugins = [];
        entries = [];
        entryByObject = [];
        selectedIndex = -1;
        background = null;
        nav = new Nav();
        itemsRoot = new h2d.Object(this);
        buildFromStyle();
    }

    function buildFromStyle():Void {
        if( style.background != null )
            background = new h2d.Bitmap(style.background, this);

        for( factory in style.pluginFactories ) {
            var plugin = factory(this);
            if( plugin != null ) {
                plugins.push(plugin);
                plugin.onAttach();
            }
        }

        for( callback in style.onInitCallbacks )
            callback(this);
    }

    public function setChoices(options:Array<MultiChoiceOption>):Void {
        if( options == null ) throw "MultiChoiceBox.setChoices requires a non-null options array.";

        clearRenderedChoices();
        for( option in options )
            addChoiceInternal(option, false);

        organizeChoices();
        selectFirstEnabled();
        notifyChoicesChanged();
    }

    public function clearChoices():Void {
        clearRenderedChoices();
        notifyChoicesChanged();
    }

    public function addChoice(option:MultiChoiceOption):Void {
        addChoiceInternal(option, true);
    }

    public function addOption(label:String, ?onSelect:Void -> Void, ?id:String, ?disabled:Bool = false, ?data:Dynamic):Void {
        if( label == null || label == "" ) throw "MultiChoiceBox.addOption requires a non-empty label.";
        addChoice({
            id: id,
            label: label,
            disabled: disabled,
            data: data,
            onSelect: onSelect,
        });
    }

    public function getOptions():Array<MultiChoiceOption> {
        return [for( entry in entries ) entry.option];
    }

    public function getSelectedIndex():Int {
        return selectedIndex;
    }

    public function getSelectedOption():Null<MultiChoiceOption> {
        if( selectedIndex < 0 || selectedIndex >= entries.length ) return null;
        return entries[selectedIndex].option;
    }

    public function selectIndex(index:Int):Bool {
        if( index < 0 || index >= entries.length )
            throw 'MultiChoiceBox.selectIndex index ${index} is out of range.';

        var entry = entries[index];
        if( !entry.navigable ) return false;
        return nav.setSelection(entry.root);
    }

    public inline function moveUp():Bool {
        return nav.moveUp();
    }

    public inline function moveDown():Bool {
        return nav.moveDown();
    }

    public inline function moveLeft():Bool {
        return nav.moveLeft();
    }

    public inline function moveRight():Bool {
        return nav.moveRight();
    }

    public function confirm():Bool {
        return nav.selectCurrent();
    }

    public function cancel():Void {
        for( plugin in plugins ) plugin.onCancel();
        emit("cancelled", null);
    }

    public dynamic function open():Future {
        alpha = 1;
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
        remove();
        return Future.immediate();
    }

    public function set(key:String, value:Dynamic):Void {
        if( key == null || key == "" ) throw "MultiChoiceBox.set requires a non-empty key.";
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

    public function organizeChoices():Void {
        switch( style.layout ) {
        case Vertical:
            organizeVertical();
        case Horizontal:
            organizeHorizontal();
        case Grid(numCols):
            organizeGrid(numCols);
        }
    }

    public function getContentBounds(?relativeTo:h2d.Object):h2d.col.Bounds {
        return itemsRoot.getBounds(relativeTo == null ? this : relativeTo);
    }

    override function onRemove():Void {
        super.onRemove();
        for( plugin in plugins ) plugin.onDetach();
    }

    function addChoiceInternal(option:MultiChoiceOption, notify:Bool):Void {
        validateOption(option);

        var renderer = createRenderer(option);
        var root = renderer.getRoot();
        if( root == null ) throw "MultiChoiceBox renderer returned a null root object.";

        renderer.setOption(option);
        var isDisabled = option.disabled == true;
        renderer.setDisabled(isDisabled);
        renderer.setSelected(false);
        itemsRoot.addChild(root);

        var entry:MultiChoiceEntry = {
            option: option,
            root: root,
            renderer: renderer,
            navigable: !isDisabled,
        };
        entries.push(entry);
        entryByObject.set(root, entry);

        if( entry.navigable ) {
            nav.bind(root, function(event) {
                handleNavEvent(entry, event);
            }, option);
        }

        organizeChoices();

        if( selectedIndex < 0 )
            selectFirstEnabled();

        if( notify )
            notifyChoicesChanged();
    }

    function clearRenderedChoices():Void {
        nav.clear();
        selectedIndex = -1;

        for( entry in entries )
            entry.root.remove();

        entries = [];
        entryByObject = [];
    }

    function notifyChoicesChanged():Void {
        var options = getOptions();
        for( plugin in plugins ) plugin.onChoicesChanged(options);
        emit("choicesChanged", options);
    }

    function selectFirstEnabled():Void {
        for( i in 0...entries.length ) {
            if( entries[i].navigable ) {
                nav.setSelection(entries[i].root);
                return;
            }
        }
        selectedIndex = -1;
    }

    function handleNavEvent(entry:MultiChoiceEntry, event:NavEvent):Void {
        switch( event ) {
        case Enter:
            entry.renderer.setSelected(true);
            handleSelectionEntered(entry);
        case Leave:
            entry.renderer.setSelected(false);
        case Selected:
            handleSelectionConfirmed(entry);
        }
    }

    function handleSelectionEntered(entry:MultiChoiceEntry):Void {
        var newIndex = entries.indexOf(entry);
        if( newIndex < 0 ) return;

        var previousIndex = selectedIndex;
        var previousOption = previousIndex >= 0 && previousIndex < entries.length ? entries[previousIndex].option : null;
        selectedIndex = newIndex;

        for( plugin in plugins )
            plugin.onSelectionChanged(newIndex, entry.option, previousIndex, previousOption);

        emit("selectionChanged", {
            index: newIndex,
            option: entry.option,
            previousIndex: previousIndex,
            previousOption: previousOption,
        });
    }

    function handleSelectionConfirmed(entry:MultiChoiceEntry):Void {
        var index = entries.indexOf(entry);
        if( index < 0 ) return;

        if( entry.option.onSelect != null )
            entry.option.onSelect();

        for( plugin in plugins )
            plugin.onConfirm(index, entry.option);

        emit("confirmed", {
            index: index,
            option: entry.option,
        });
    }

    function createRenderer(option:MultiChoiceOption):MultiChoiceItemRenderer {
        if( style.itemRendererFactory != null ) {
            var renderer = style.itemRendererFactory(this, option);
            if( renderer == null ) throw "MultiChoiceBox itemRendererFactory returned a null renderer.";
            return renderer;
        }

        var font = style.resolveFont();
        return new BasicTextMultiChoiceItemRenderer(
            font,
            style.textColor,
            style.selectedTextColor,
            style.disabledTextColor
        );
    }

    function validateOption(option:MultiChoiceOption):Void {
        if( option == null ) throw "MultiChoiceBox option cannot be null.";
        if( option.label == null || option.label == "" ) throw "MultiChoiceBox option label must be non-empty.";
    }

    function organizeVertical():Void {
        var maxWidth:Float = 0;
        if( style.centerItems ) {
            for( entry in entries ) {
                var bounds = entry.root.getBounds(itemsRoot);
                if( bounds.width > maxWidth )
                    maxWidth = bounds.width;
            }
        }

        var currentY = style.margin;
        for( entry in entries ) {
            var bounds = entry.root.getBounds(itemsRoot);
            if( style.centerItems )
                entry.root.x = style.margin + ((maxWidth - bounds.width) * 0.5) - bounds.xMin;
            else
                entry.root.x = style.margin - bounds.xMin;

            entry.root.y = currentY - bounds.yMin;
            currentY += bounds.height + style.padding;
        }
    }

    function organizeHorizontal():Void {
        var currentX = style.margin;
        for( entry in entries ) {
            var bounds = entry.root.getBounds(itemsRoot);
            entry.root.x = currentX - bounds.xMin;
            entry.root.y = style.margin - bounds.yMin;
            currentX += bounds.width + style.padding;
        }
    }

    function organizeGrid(numCols:Int):Void {
        if( numCols <= 0 ) throw "MultiChoiceBox grid layout requires numCols > 0.";
        if( entries.length == 0 ) return;

        var colWidths:Array<Float> = [];
        for( i in 0...numCols )
            colWidths[i] = 0;

        var rowHeights:Array<Float> = [];

        for( i in 0...entries.length ) {
            var entry = entries[i];
            var col = i % numCols;
            var row = Std.int(i / numCols);
            var bounds = entry.root.getBounds(itemsRoot);

            if( colWidths[col] < bounds.width )
                colWidths[col] = bounds.width;

            if( rowHeights.length <= row )
                rowHeights[row] = bounds.height;
            else if( rowHeights[row] < bounds.height )
                rowHeights[row] = bounds.height;
        }

        var xOffsets:Array<Float> = [];
        var accumX = style.margin;
        for( col in 0...numCols ) {
            xOffsets[col] = accumX;
            accumX += colWidths[col] + style.padding;
        }

        var yOffsets:Array<Float> = [];
        var accumY = style.margin;
        for( row in 0...rowHeights.length ) {
            yOffsets[row] = accumY;
            accumY += rowHeights[row] + style.padding;
        }

        for( i in 0...entries.length ) {
            var entry = entries[i];
            var col = i % numCols;
            var row = Std.int(i / numCols);
            var bounds = entry.root.getBounds(itemsRoot);
            entry.root.x = xOffsets[col] - bounds.xMin;
            entry.root.y = yOffsets[row] - bounds.yMin;
        }
    }

}
