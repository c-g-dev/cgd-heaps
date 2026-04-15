package h2d;

class DebugBoxOverlay extends h2d.Graphics {

	var target : h2d.Object;
	var bounds : h2d.col.Bounds;

	public function new(target:h2d.Object) {
		super();
		this.target = target;
		bounds = new h2d.col.Bounds();
	}

	public function updateAttachment() {
		var scene = target.getScene();
		if ( scene == null ) {
			if ( parent != null ) remove();
			return;
		}
		if ( parent != scene )
			scene.addChild(this);
		scene.over(this);
	}

	override function sync(ctx:RenderContext) {
		updateAttachment();
		clear();
		var scene = target.getScene();
		if ( scene != null ) {
			target.getBounds(scene, bounds);
			lineStyle(1, 0xFF00FF, 1);
			drawRect(bounds.xMin, bounds.yMin, bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin);
		}
		super.sync(ctx);
	}
}
