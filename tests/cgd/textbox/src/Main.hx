package;

import cgd.ui.SuperTextLibrary;
import cgd.ui.SuperText;
import cgd.ui.textbox.Textbox;
import cgd.ui.textbox.TextboxSpeakerPlugin;
import cgd.ui.textbox.TextboxStyles;
import cgd.ui.textbox.TextboxStyles.TextboxStyle;
import hxd.App;
import hxd.Key;

class Main extends App {
    var textbox:Textbox;
    var lines:Array<String>;
    var currentLineIndex:Int;
    var readyForNextLine:Bool;

    static function main() {
        new Main();
    }

    override function init() {
        hxd.Res.initEmbed();

        var lib = new SuperTextLibrary();
        SuperText.configurable = lib;
        var defaultFont = hxd.res.DefaultFont.get();
        lib.registerFont("default", defaultFont);

        var styleName = "textbox-smoke-test";
        if( !TextboxStyles.exists(styleName) ) {
            var style = new TextboxStyle();
            style.font = defaultFont;
            style.textAreaX = 24;
            style.textAreaY = 24;
            style.textAreaWidth = 560;
            style.speed = 44;
            style.maxLines = 3;
            style.pluginFactories.push(function(target) {
                return new TextboxSpeakerPlugin(target, defaultFont, null, 24, 0);
            });
            TextboxStyles.register(styleName, style);
        }

        textbox = new Textbox(styleName, s2d);
        textbox.x = 24;
        textbox.y = 320;

        textbox.on("stateChanged", function(state) {
            trace('textbox state: ' + Std.string(state));
        });
        textbox.on("speakerChanged", function(speaker) {
            trace('speaker changed: ' + (speaker == null ? "(none)" : Std.string(speaker)));
        });
        textbox.on("complete", function(_) {
            readyForNextLine = true;
            trace('line complete. press ENTER for next line.');
        });

        lines = [
            '<p speaker="Narrator">Textbox smoke test line one. Press SPACE to auto-fill and advance paragraphs.</p><p>Second paragraph verifies WaitForAdvance behavior.</p>',
            '<p speaker="Guide">Line two uses a different speaker and confirms plugin updates.</p><p>Press SPACE to continue writing and ENTER after completion.</p>',
            "<p>Final line. If this completes, the textbox test case is working.</p>"
        ];
        currentLineIndex = 0;
        readyForNextLine = false;
        startCurrentLine();
    }

    override function update(dt:Float) {
        super.update(dt);

        if( Key.isPressed(Key.SPACE) )
            textbox.advance();

        if( Key.isPressed(Key.ENTER) && readyForNextLine )
            startNextLine();
    }

    function startCurrentLine():Void {
        if( currentLineIndex >= lines.length ) {
            trace("Textbox smoke test finished.");
            return;
        }

        readyForNextLine = false;
        var html = lines[currentLineIndex];
        trace('writing line ' + (currentLineIndex + 1) + "/" + lines.length);
        textbox.write(html);
    }

    function startNextLine():Void {
        currentLineIndex++;
        startCurrentLine();
    }
}
