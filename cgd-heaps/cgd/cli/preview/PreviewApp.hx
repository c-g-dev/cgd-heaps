package cgd.cli.preview;

class PreviewApp extends hxd.App {

    static function main() {
        new PreviewApp();
    }

    override function init() {
        hxd.Res.initLocal();
        LaunchMacro.launch(this);
    }

}
