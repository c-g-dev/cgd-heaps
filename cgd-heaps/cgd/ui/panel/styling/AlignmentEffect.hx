package cgd.ui.panel.styling;

import cgd.ui.panel.Panel;

enum PanelHorizontalAlignment {
    Left;
    Center;
    Right;
}

enum PanelVerticalAlignment {
    Top;
    Center;
    Bottom;
}

class AlignmentEffect {

    public static function align(panel:Panel, horizontal:PanelHorizontalAlignment, vertical:PanelVerticalAlignment, ?marginX:Float = 0, ?marginY:Float = 0):Void {
        if( panel == null ) throw "AlignmentEffect.align requires a non-null panel.";

        var bounds = panel.getBounds();
        var window = hxd.Window.getInstance();

        switch( horizontal ) {
        case Left:
            panel.x = marginX - bounds.xMin;
        case Center:
            panel.x = ((window.width - bounds.width) * 0.5) - bounds.xMin;
        case Right:
            panel.x = window.width - marginX - bounds.width - bounds.xMin;
        }

        switch( vertical ) {
        case Top:
            panel.y = marginY - bounds.yMin;
        case Center:
            panel.y = ((window.height - bounds.height) * 0.5) - bounds.yMin;
        case Bottom:
            panel.y = window.height - marginY - bounds.height - bounds.yMin;
        }
    }

    public static inline function toCenter(panel:Panel):Void {
        align(panel, Center, Center);
    }

    public static inline function toBottomCenter(panel:Panel, ?marginY:Float = 0):Void {
        align(panel, Center, Bottom, 0, marginY);
    }

}
