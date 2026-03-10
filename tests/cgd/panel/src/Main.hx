package;

import cgd.ui.multichoice.MultiChoiceBox;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceStyle;
import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceStyles;
import cgd.ui.panel.Panel;
import cgd.ui.panel.PanelManager;
import cgd.ui.panel.PanelStyles.PanelHAlign;
import cgd.ui.panel.PanelStyles.PanelSizing;
import cgd.ui.panel.PanelStyles.PanelStyle;
import cgd.ui.panel.PanelStyles.PanelStyles;
import cgd.ui.panel.styling.AlignmentEffect;
import cgd.ui.panel.styling.BasicOpenCloseEffect;
import hxd.App;
import hxd.Key;

class Main extends App {

    static inline var PANEL_STYLE_NAME:String = "panel-smoke-style";
    static inline var MENU_STYLE_NAME:String = "panel-smoke-menu";

    var panelManager:PanelManager;
    var panel:Null<Panel>;
    var menu:Null<MultiChoiceBox>;
    var defaultFont:h2d.Font;

    static function main() {
        new Main();
    }

    override function init() {
        defaultFont = hxd.res.DefaultFont.get();
        registerMenuStyle();
        registerPanelStyle();

        panelManager = new PanelManager(s2d);
        openPanel();
    }

    override function update(dt:Float) {
        super.update(dt);

        if( menu != null ) {
            if( Key.isPressed(Key.UP) )
                menu.moveUp();
            if( Key.isPressed(Key.DOWN) )
                menu.moveDown();
            if( Key.isPressed(Key.LEFT) )
                menu.moveLeft();
            if( Key.isPressed(Key.RIGHT) )
                menu.moveRight();
            if( Key.isPressed(Key.ENTER) )
                menu.confirm();
        }

        if( Key.isPressed(Key.ESCAPE) && panel != null ) {
            panelManager.pop().then(function(_) {
                panel = null;
                menu = null;
            });
        }

        if( Key.isPressed(Key.TAB) && panel == null )
            openPanel();
    }

    function openPanel():Void {
        var nextPanel = new Panel(PANEL_STYLE_NAME);
        panel = nextPanel;
        panelManager.push(nextPanel);

        var header = new h2d.Text(defaultFont);
        header.text = "Panel Smoke Test";
        header.textColor = 0xFFFFFF;

        var content = new h2d.Object();

        var description = new h2d.Text(defaultFont, content);
        description.text = "This panel auto-sizes around its slots.\nIt can host existing widgets inside contentRoot.";
        description.textColor = 0xD7E3FF;

        menu = new MultiChoiceBox(MENU_STYLE_NAME, content);
        menu.y = description.getBounds(content).height + 18;
        menu.addOption("Inspect", function() trace("selected INSPECT"));
        menu.addOption("Equip", function() trace("selected EQUIP"));
        menu.addOption("Drop", function() trace("selected DROP"));
        menu.addOption("Disabled Entry", null, "disabled", true);

        var footer = new h2d.Text(defaultFont);
        footer.text = "Arrows move  ENTER confirm  ESC close  TAB reopen";
        footer.textColor = 0xAAB8E8;

        nextPanel.setHeader(header);
        nextPanel.setContent(content);
        nextPanel.setFooter(footer);
        AlignmentEffect.toCenter(nextPanel);
        BasicOpenCloseEffect.apply(nextPanel);
        nextPanel.open();
    }

    function registerMenuStyle():Void {
        if( MultiChoiceStyles.exists(MENU_STYLE_NAME) ) return;

        var style = new MultiChoiceStyle();
        style.font = defaultFont;
        style.margin = 0;
        style.padding = 8;
        style.textColor = 0xFFFFFF;
        style.selectedTextColor = 0xFFD166;
        style.disabledTextColor = 0x66708F;
        MultiChoiceStyles.register(MENU_STYLE_NAME, style);
    }

    function registerPanelStyle():Void {
        if( PanelStyles.exists(PANEL_STYLE_NAME) ) return;

        var style = new PanelStyle();
        style.background = h2d.Tile.fromColor(0x24324A, 32, 32);
        style.useScaleGrid = true;
        style.borderLeft = 6;
        style.borderTop = 6;
        style.borderRight = 6;
        style.borderBottom = 6;
        style.paddingLeft = 18;
        style.paddingTop = 18;
        style.paddingRight = 18;
        style.paddingBottom = 18;
        style.slotGap = 12;
        style.slotAlign = Center;
        style.sizing = FitContentMin(420, 220);
        PanelStyles.register(PANEL_STYLE_NAME, style);
    }

}
