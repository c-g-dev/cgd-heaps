package cgd.ui.textbox;

enum TextboxCursorMode {
    NextLine;
    EndOfParagraph;
}

class TextboxCursor extends h2d.Object {

    public var mode(default, null):TextboxCursorMode;

    public function new(?parent:h2d.Object) {
        super(parent);
        mode = NextLine;
        visible = false;
    }

    public function setNextLineMode():Void {
        mode = NextLine;
    }

    public function setEndOfParagraphMode():Void {
        mode = EndOfParagraph;
    }

    public function show():Void {
        visible = true;
    }

    public function hide():Void {
        visible = false;
    }

}
