package cgd.ui.textbox;

import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;

class TextboxCursorPlugin extends TextboxPlugin {

    var cursor:TextboxCursor;

    public function new(textbox:Textbox, cursorFactory:Void -> TextboxCursor) {
        super(textbox);
        if( cursorFactory == null ) throw "TextboxCursorPlugin requires a non-null cursorFactory.";
        cursor = cursorFactory();
        if( cursor == null ) throw "TextboxCursorPlugin cursorFactory returned null.";
        textbox.addChild(cursor);
        cursor.visible = false;
    }

    override public function onStateChanged(state:SuperTextTypewriterOnFrameState):Void {
        switch( state ) {
        case AllLinesAllocated:
            cursor.setNextLineMode();
            cursor.show();
        case ParagraphBreak:
            cursor.setEndOfParagraphMode();
            cursor.show();
        case Writing, DeallocatingLines, NoMoreParagraphs:
            cursor.hide();
        }
    }

    override public function onAdvance():Void {
        cursor.hide();
    }

    override public function onComplete():Void {
        cursor.hide();
    }

    override public function onDetach():Void {
        cursor.hide();
        cursor.remove();
    }

    public function getCursor():TextboxCursor {
        return cursor;
    }

}
