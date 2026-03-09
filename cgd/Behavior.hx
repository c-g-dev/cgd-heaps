package cgd;


class Behavior extends h2d.Object {
    public var onFrame: Float -> Void = (dt) -> {};

    public function new(?onFrame: Float -> Void) {
        super();
        this.visible = false;
        if (onFrame != null) {
            this.onFrame = onFrame;
        }
    }

    override function set_visible(b) {
        this.visible = false;
		return false;
	}

    public override function onUpdate(dt:Float) {
        onFrame(dt);
    }
}