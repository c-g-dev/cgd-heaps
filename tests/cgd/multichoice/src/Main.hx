package;

import cgd.ui.multichoice.MultiChoiceBox;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceStyle;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceStyles;
import hxd.App;
import hxd.Key;

class Main extends App {
    var multiChoice:MultiChoiceBox;

    static function main() {
        new Main();
    }

    override function init() {
        var styleName = "multichoice-smoke-test";
        if( !MultiChoiceStyles.exists(styleName) ) {
            var style = new MultiChoiceStyle();
            style.font = hxd.res.DefaultFont.get();
            style.margin = 16;
            style.padding = 12;
            style.centerItems = true;
            style.textColor = 0xFFFFFF;
            style.selectedTextColor = 0x00FF00;
            style.disabledTextColor = 0x555555;
            MultiChoiceStyles.register(styleName, style);
        }

        multiChoice = new MultiChoiceBox(styleName, s2d);
        multiChoice.x = 40;
        multiChoice.y = 80;
        multiChoice.addOption("New Game", function() trace("selected NEW_GAME"));
        multiChoice.addOption("Load Game", function() trace("selected LOAD_GAME"));
        multiChoice.addOption("Options", function() trace("selected OPTIONS"));
        multiChoice.addOption("Quit", function() trace("selected QUIT"));
        multiChoice.addOption("Disabled Entry", null, "disabled", true);

        multiChoice.on("selectionChanged", function(data) {
            trace('selection changed: index=${data.index}, label=${data.option.label}');
        });
        multiChoice.on("confirmed", function(data) {
            trace('confirmed: index=${data.index}, label=${data.option.label}');
        });
        multiChoice.on("cancelled", function(_) {
            trace("cancelled");
        });
    }

    override function update(dt:Float) {
        super.update(dt);

        if( Key.isPressed(Key.UP) )
            multiChoice.moveUp();
        if( Key.isPressed(Key.DOWN) )
            multiChoice.moveDown();
        if( Key.isPressed(Key.LEFT) )
            multiChoice.moveLeft();
        if( Key.isPressed(Key.RIGHT) )
            multiChoice.moveRight();
        if( Key.isPressed(Key.ENTER) )
            multiChoice.confirm();
        if( Key.isPressed(Key.ESCAPE) )
            multiChoice.cancel();
    }
}
