package cgd.ui.panel;

enum PanelSizing {
    Fixed(width:Float, height:Float);
    FitContent;
    FitContentMin(minWidth:Float, minHeight:Float);
}

enum PanelHAlign {
    Left;
    Center;
    Right;
}

class PanelStyle {

    public var background:Null<h2d.Tile>;
    public var useScaleGrid:Bool;
    public var borderLeft:Int;
    public var borderTop:Int;
    public var borderRight:Int;
    public var borderBottom:Int;
    public var tileBorders:Bool;
    public var tileCenter:Bool;
    public var ignoreScale:Bool;
    public var borderScale:Float;
    public var paddingLeft:Float;
    public var paddingTop:Float;
    public var paddingRight:Float;
    public var paddingBottom:Float;
    public var slotGap:Float;
    public var slotAlign:PanelHAlign;
    public var sizing:PanelSizing;
    public var pluginFactories:Array<Panel -> PanelPlugin>;
    public var onInitCallbacks:Array<Panel -> Void>;

    public function new() {
        background = null;
        useScaleGrid = false;
        borderLeft = 0;
        borderTop = 0;
        borderRight = 0;
        borderBottom = 0;
        tileBorders = false;
        tileCenter = false;
        ignoreScale = false;
        borderScale = 1;
        paddingLeft = 0;
        paddingTop = 0;
        paddingRight = 0;
        paddingBottom = 0;
        slotGap = 0;
        slotAlign = Left;
        sizing = FitContent;
        pluginFactories = [];
        onInitCallbacks = [];
    }

    public function addOnInit(callback:Panel -> Void):Void {
        if( callback == null ) throw "PanelStyle.addOnInit requires a non-null callback.";
        onInitCallbacks.push(callback);
    }

}

class PanelStyles {

    static var styles:Map<String, PanelStyle> = [];

    public static function register(name:String, style:PanelStyle):Void {
        if( name == null || name == "" ) throw "PanelStyles.register requires a non-empty name.";
        if( style == null ) throw 'PanelStyles.register("${name}") received null style.';
        styles.set(name, style);
    }

    public static function get(name:String):PanelStyle {
        if( name == null || name == "" ) throw "PanelStyles.get requires a non-empty name.";
        var style = styles.get(name);
        if( style == null ) throw 'PanelStyles: style "${name}" is not registered.';
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
