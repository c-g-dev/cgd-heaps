package cgd.ui.textbox;

import cgd.ui.SuperTextTypewriter.SuperTextTypewriterDeallocateLinesEffect;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterParagraphBreak;
import cgd.ui.textbox.styling.TestStyle;

class TextboxStyle {

    public var background:Null<h2d.Tile>;
    public var font:Null<h2d.Font>;
    public var fontName:Null<String>;
    public var textAreaX:Float;
    public var textAreaY:Float;
    public var textAreaWidth:Float;
    public var speed:Float;
    public var maxLines:Int;
    public var paragraphBreakMode:SuperTextTypewriterParagraphBreak;
    public var deallocateLinesEffect:SuperTextTypewriterDeallocateLinesEffect;
    public var pluginFactories:Array<Textbox -> TextboxPlugin>;
    public var onInitCallbacks:Array<Textbox -> Void>;

    public function new() {
        background = null;
        font = null;
        fontName = null;
        textAreaX = 0;
        textAreaY = 0;
        textAreaWidth = -1;
        speed = 30;
        maxLines = -1;
        paragraphBreakMode = WaitForAdvance;
        deallocateLinesEffect = Clear;
        pluginFactories = [];
        onInitCallbacks = [];
    }

    public function addOnInit(callback:Textbox -> Void):Void {
        if( callback == null ) throw "TextboxStyle.addOnInit requires a non-null callback.";
        onInitCallbacks.push(callback);
    }

}

class TextboxStyles {

    static var styles:Map<String, TextboxStyle> = [];

    public static function register(name:String, style:TextboxStyle):Void {
        if( name == null || name == "" ) throw "TextboxStyles.register requires a non-empty name.";
        if( style == null ) throw 'TextboxStyles.register("${name}") received null style.';
        styles.set(name, style);
    }

    public static function get(name:String):TextboxStyle {
        if( name == null || name == "" ) throw "TextboxStyles.get requires a non-empty name.";
        var style = styles.get(name);
        if( style == null ) throw 'TextboxStyles: style "${name}" is not registered.';
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

    public static function __init__():Void {
        Runtime.afterResourcesLoaded(function() {
            register("test-style", TestStyle.create());
        });
    }

}
