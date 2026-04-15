package cgd.ui.textbox;

typedef TextboxSpeakerDef = {
    ?portrait:h2d.Tile,
    ?displayName:String,
}

class TextboxSpeakerPlugin extends TextboxPlugin {

    var titleText:Null<h2d.Text>;
    var titleBg:Null<h2d.Bitmap>;
    var image:Null<h2d.Bitmap>;
    var titleX:Float;
    var titleY:Float;
    var imageX:Float;
    var imageY:Float;
    var speakers:Map<String, TextboxSpeakerDef>;

    public function new(
        textbox:Textbox,
        font:h2d.Font,
        ?titleBackground:h2d.Tile,
        ?titleX:Float = 0,
        ?titleY:Float = 0,
        ?imageX:Float = 0,
        ?imageY:Float = 0,
        ?speakers:Map<String, TextboxSpeakerDef>
    ) {
        super(textbox);
        if( font == null ) throw "TextboxSpeakerPlugin requires a non-null font.";
        this.titleX = titleX;
        this.titleY = titleY;
        this.imageX = imageX;
        this.imageY = imageY;
        this.speakers = speakers != null ? speakers : [];
        this.image = null;

        if( titleBackground != null ) {
            titleBg = new h2d.Bitmap(titleBackground, textbox);
            titleBg.x = titleX;
            titleBg.y = titleY;
            titleBg.visible = false;
        }

        titleText = new h2d.Text(font, textbox);
        titleText.x = titleX;
        titleText.y = titleY;
        titleText.visible = false;
    }

    override public function onBeforeWrite(html:String):Void {
        extractSpeakerFromHtml(html);
    }

    override public function onPropertyChanged(key:String, value:Dynamic):Void {
        if( key == "speaker" ) applySpeaker(value);
    }

    override public function onDetach():Void {
        if( titleText != null ) { titleText.remove(); titleText = null; }
        if( titleBg != null ) { titleBg.remove(); titleBg = null; }
        if( image != null ) { image.remove(); image = null; }
    }

    public function registerSpeaker(name:String, def:TextboxSpeakerDef):Void {
        if( name == null || name == "" ) throw "TextboxSpeakerPlugin.registerSpeaker requires a non-empty name.";
        speakers.set(name, def);
    }

    function applySpeaker(speakerName:Dynamic):Void {
        var name:String = speakerName != null ? Std.string(speakerName) : null;

        if( name == null || name == "" ) {
            if( titleText != null ) titleText.visible = false;
            if( titleBg != null ) titleBg.visible = false;
            if( image != null ) image.visible = false;
            textbox.emit("speakerChanged", null);
            return;
        }

        var speakerDef:TextboxSpeakerDef = speakers.get(name);

        if( titleText != null ) {
            var displayName = speakerDef != null && speakerDef.displayName != null ? speakerDef.displayName : name;
            titleText.text = displayName;
            titleText.visible = true;
            if( titleBg != null ) titleBg.visible = true;
        }

        if( speakerDef != null && speakerDef.portrait != null ) {
            if( image == null ) {
                image = new h2d.Bitmap(speakerDef.portrait, textbox);
                image.x = imageX;
                image.y = imageY;
            } else {
                image.tile = speakerDef.portrait;
            }
            image.visible = true;
        } else if( image != null ) {
            image.visible = false;
        }

        textbox.emit("speakerChanged", name);
    }

    function extractSpeakerFromHtml(html:String):Void {
        var doc = Xml.parse(html);
        findSpeakerAttribute(doc);
    }

    function findSpeakerAttribute(node:Xml):Bool {
        for( child in node ) {
            if( child.nodeType == Xml.Element ) {
                if( child.exists("speaker") ) {
                    textbox.set("speaker", child.get("speaker"));
                    return true;
                }
                if( findSpeakerAttribute(child) ) return true;
            }
        }
        return false;
    }

}
