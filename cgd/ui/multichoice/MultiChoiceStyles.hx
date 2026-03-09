package cgd.ui.multichoice;

import cgd.ui.SuperText;

enum MultiChoiceLayout {
    Vertical;
    Horizontal;
    Grid(numCols:Int);
}

typedef MultiChoiceOption = {
    var label:String;
    @:optional var id:String;
    @:optional var disabled:Bool;
    @:optional var data:Dynamic;
    @:optional var onSelect:Void -> Void;
}

interface MultiChoiceItemRenderer {
    function getRoot():h2d.Object;
    function setOption(option:MultiChoiceOption):Void;
    function setSelected(selected:Bool):Void;
    function setDisabled(disabled:Bool):Void;
}

class BasicTextMultiChoiceItemRenderer implements MultiChoiceItemRenderer {

    var root:h2d.Text;
    var normalColor:Int;
    var selectedColor:Int;
    var disabledColor:Int;
    var isDisabled:Bool;

    public function new(font:h2d.Font, normalColor:Int, selectedColor:Int, disabledColor:Int) {
        if( font == null ) throw "BasicTextMultiChoiceItemRenderer requires a non-null font.";
        root = new h2d.Text(font);
        root.smooth = true;
        this.normalColor = normalColor;
        this.selectedColor = selectedColor;
        this.disabledColor = disabledColor;
        isDisabled = false;
        root.textColor = normalColor;
    }

    public function getRoot():h2d.Object {
        return root;
    }

    public function setOption(option:MultiChoiceOption):Void {
        if( option == null ) throw "BasicTextMultiChoiceItemRenderer.setOption requires a non-null option.";
        root.text = option.label;
    }

    public function setSelected(selected:Bool):Void {
        if( isDisabled ) {
            root.textColor = disabledColor;
            return;
        }
        root.textColor = selected ? selectedColor : normalColor;
    }

    public function setDisabled(disabled:Bool):Void {
        isDisabled = disabled;
        root.textColor = disabled ? disabledColor : normalColor;
    }

}

class MultiChoiceStyle {

    public var background:Null<h2d.Tile>;
    public var font:Null<h2d.Font>;
    public var fontName:Null<String>;
    public var layout:MultiChoiceLayout;
    public var margin:Float;
    public var padding:Float;
    public var centerItems:Bool;
    public var textColor:Int;
    public var selectedTextColor:Int;
    public var disabledTextColor:Int;
    public var itemRendererFactory:Null<(MultiChoiceBox, MultiChoiceOption) -> MultiChoiceItemRenderer>;
    public var pluginFactories:Array<MultiChoiceBox -> MultiChoicePlugin>;
    public var onInitCallbacks:Array<MultiChoiceBox -> Void>;

    public function new() {
        background = null;
        font = null;
        fontName = null;
        layout = Vertical;
        margin = 10;
        padding = 10;
        centerItems = false;
        textColor = 0xFFFFFF;
        selectedTextColor = 0xFFFF00;
        disabledTextColor = 0x808080;
        itemRendererFactory = null;
        pluginFactories = [];
        onInitCallbacks = [];
    }

    public function addOnInit(callback:MultiChoiceBox -> Void):Void {
        if( callback == null ) throw "MultiChoiceStyle.addOnInit requires a non-null callback.";
        onInitCallbacks.push(callback);
    }

    public function resolveFont():h2d.Font {
        if( font != null ) return font;
        if( fontName != null ) {
            var fonts = SuperText.configurable.getFonts();
            if( fonts == null ) throw "MultiChoiceStyle.resolveFont could not access SuperText fonts.";
            var resolved = fonts.get(fontName);
            if( resolved == null ) throw 'MultiChoiceStyle font "${fontName}" is not registered in SuperText.configurable.';
            return resolved;
        }
        throw "MultiChoice style must specify either font or fontName.";
    }

}

class MultiChoiceStyles {

    static var styles:Map<String, MultiChoiceStyle> = [];

    public static function register(name:String, style:MultiChoiceStyle):Void {
        if( name == null || name == "" ) throw "MultiChoiceStyles.register requires a non-empty name.";
        if( style == null ) throw 'MultiChoiceStyles.register("${name}") received null style.';
        styles.set(name, style);
    }

    public static function get(name:String):MultiChoiceStyle {
        if( name == null || name == "" ) throw "MultiChoiceStyles.get requires a non-empty name.";
        var style = styles.get(name);
        if( style == null ) throw 'MultiChoiceStyles: style "${name}" is not registered.';
        return style;
    }

    public static function exists(name:String):Bool {
        if( name == null ) return false;
        return styles.exists(name);
    }

    public static function remove(name:String):Void {
        if( name == null ) return;
        styles.remove(name);
    }

}
