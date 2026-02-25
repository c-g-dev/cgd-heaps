package cgd.ui.textbox;

import heaps.coroutine.Future;
import cgd.ui.SuperText;
import cgd.ui.SuperTextTypewriter;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterRequest;
import cgd.ui.textbox.TextboxStyles.TextboxStyle;

class Textbox extends h2d.Object {

    var style:TextboxStyle;
    var text:SuperText;
    var typewriter:Null<SuperTextTypewriter>;
    var bg:Null<h2d.Bitmap>;
    var properties:Map<String, Dynamic>;
    var listeners:Map<String, Array<Dynamic -> Void>>;
    var plugins:Array<TextboxPlugin>;
    var pendingAdvance:Bool;
    var lastReportedState:Null<SuperTextTypewriterOnFrameState>;
    var currentCompletion:Null<Future>;

    public function new(styleName:String, ?parent:h2d.Object) {
        super(parent);
        style = TextboxStyles.get(styleName);
        properties = [];
        listeners = [];
        plugins = [];
        pendingAdvance = false;
        lastReportedState = null;
        currentCompletion = null;
        typewriter = null;
        bg = null;
        buildFromStyle();
    }

    function buildFromStyle():Void {
        if( style.background != null )
            bg = new h2d.Bitmap(style.background, this);

        var font = resolveFont();
        text = new SuperText(font, this);
        text.x = style.textAreaX;
        text.y = style.textAreaY;
        if( style.textAreaWidth > 0 ) text.maxWidth = style.textAreaWidth;

        for( factory in style.pluginFactories ) {
            var plugin = factory(this);
            if( plugin != null ) {
                plugins.push(plugin);
                plugin.onAttach();
            }
        }
    }

    function resolveFont():h2d.Font {
        if( style.font != null ) return style.font;
        if( style.fontName != null ) {
            var fonts = SuperText.configurable.getFonts();
            if( fonts == null ) throw "Textbox: SuperText.configurable fonts map is null.";
            var font = fonts.get(style.fontName);
            if( font == null ) throw 'Textbox: font "${style.fontName}" is not registered in SuperText.configurable.';
            return font;
        }
        throw "Textbox style must specify either font or fontName.";
    }

    public function write(html:String):Future {
        if( currentCompletion != null && !currentCompletion.isComplete )
            throw "Textbox.write called while a previous write is still in progress.";

        if( html == null || StringTools.trim(html) == "" ) html = "<p></p>";

        for( plugin in plugins ) plugin.onBeforeWrite(html);
        emit("write", html);

        pendingAdvance = false;
        lastReportedState = null;

        text.htmlText = html;
        typewriter = text.createTypewriter(
            style.speed,
            style.maxLines,
            style.paragraphBreakMode,
            textboxController,
            style.deallocateLinesEffect
        );

        var future = typewriter.start();
        currentCompletion = future;

        future.then(function(_) {
            for( plugin in plugins ) plugin.onComplete();
            emit("complete", null);
            currentCompletion = null;
        });

        return future;
    }

    public function advance():Void {
        pendingAdvance = true;
        for( plugin in plugins ) plugin.onAdvance();
        emit("advance", null);
    }

    public function set(key:String, value:Dynamic):Void {
        if( key == null || key == "" ) throw "Textbox.set requires a non-empty key.";
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

    public function getSuperText():SuperText {
        return text;
    }

    public function getTypewriter():Null<SuperTextTypewriter> {
        return typewriter;
    }

    public function isWriting():Bool {
        return currentCompletion != null && !currentCompletion.isComplete;
    }

    override function onRemove():Void {
        super.onRemove();
        for( plugin in plugins ) plugin.onDetach();
    }

    function textboxController(state:SuperTextTypewriterOnFrameState):SuperTextTypewriterRequest {
        if( lastReportedState != state ) {
            lastReportedState = state;
            for( plugin in plugins ) plugin.onStateChanged(state);
            emit("stateChanged", state);
        }

        if( pendingAdvance ) {
            pendingAdvance = false;
            switch( state ) {
            case AllLinesAllocated:
                return Advance;
            case ParagraphBreak:
                return Advance;
            case NoMoreParagraphs:
                return Finish;
            case Writing:
                return AutoFill;
            case DeallocatingLines:
            }
        }

        switch( state ) {
        case NoMoreParagraphs: return Finish;
        default: return Wait;
        }
    }

}
