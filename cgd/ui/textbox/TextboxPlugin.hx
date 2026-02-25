package cgd.ui.textbox;

import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;

class TextboxPlugin {

    var textbox:Textbox;

    public function new(textbox:Textbox) {
        this.textbox = textbox;
    }

    public function onAttach():Void {}

    public function onDetach():Void {}

    public function onBeforeWrite(html:String):Void {}

    public function onStateChanged(state:SuperTextTypewriterOnFrameState):Void {}

    public function onPropertyChanged(key:String, value:Dynamic):Void {}

    public function onAdvance():Void {}

    public function onComplete():Void {}

}
