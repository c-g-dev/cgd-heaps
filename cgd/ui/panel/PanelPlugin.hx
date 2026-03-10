package cgd.ui.panel;

class PanelPlugin {

    var panel:Panel;

    public function new(panel:Panel) {
        if( panel == null ) throw "PanelPlugin requires a non-null panel.";
        this.panel = panel;
    }

    public function onAttach():Void {}

    public function onDetach():Void {}

    public function onHeaderChanged(header:Null<h2d.Object>):Void {}

    public function onContentChanged(content:Null<h2d.Object>):Void {}

    public function onFooterChanged(footer:Null<h2d.Object>):Void {}

    public function onRelayout(width:Float, height:Float):Void {}

    public function onPropertyChanged(key:String, value:Dynamic):Void {}

    public function onOpen():Void {}

    public function onClose():Void {}

}
