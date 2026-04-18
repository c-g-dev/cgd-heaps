package cgd.ui.textbox.styling;

import cgd.ui.textbox.Textbox;

enum AlignmentEffectMode {
    Bottom;
    Center;
}

class AlignmentEffect {

    public static function align(textbox:Textbox, mode:AlignmentEffectMode):Void {
        if( textbox == null ) throw "AlignmentEffect.align requires a non-null textbox.";

        var panel = textbox.getPanel();
        var window = hxd.Window.getInstance();
        textbox.x = 0;

        switch( mode ) {
        case Bottom:
            textbox.y = (window.height - panel.height);
        case Center:
            textbox.y = ((window.height - panel.height) * 0.5);
        }
    }

    public static inline function toBottom(textbox:Textbox):Void {
        align(textbox, Bottom);
    }

    public static inline function toCenter(textbox:Textbox):Void {
        align(textbox, Center);
    }

}
