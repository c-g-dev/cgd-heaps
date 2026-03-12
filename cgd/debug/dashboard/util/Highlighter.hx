package cgd.debug.dashboard.util;

import cgd.debug.dashboard.HeapsDebugServer;
import h2d.Graphics;
import h2d.Interactive;
import h2d.Object;
import h2d.col.Bounds;
import h2d.col.Point;
import hxd.Event;
import hxd.EventKind;

private enum ManualEditMode {
	Idle;
	Move;
	Scale;
}

class Highlighter extends h2d.Object {
	static inline var HANDLE_SIZE:Float = 12.0;
	static inline var MIN_SCALE_SIZE:Float = 4.0;
	static inline var EPSILON:Float = 0.0001;

	static var instance: Highlighter;

	var target: Object;
	var gfx: Graphics;
	var bounds: Bounds;
	var hitArea: Interactive;
	var manualEditEnabled: Bool = false;
	var editMode: ManualEditMode = Idle;

	var dragStartPointerParent: Point;
	var dragStartPointerScene: Point;
	var dragStartObjectX: Float = 0.0;
	var dragStartObjectY: Float = 0.0;
	var dragStartScaleX: Float = 1.0;
	var dragStartScaleY: Float = 1.0;
	var dragStartBounds: Bounds;
	var scaleAnchorLocal: Point;
	var scaleAnchorParent: Point;

	public function new() {
		super();
		gfx = new Graphics(this);
		bounds = new Bounds();
		hitArea = new Interactive(1, 1, this);
		hitArea.propagateEvents = true;
		hitArea.cursor = hxd.Cursor.Default;
		hitArea.onPush = onHitAreaPush;
		dragStartPointerParent = new Point();
		dragStartPointerScene = new Point();
		dragStartBounds = new Bounds();
		scaleAnchorLocal = new Point();
		scaleAnchorParent = new Point();
	}

	public static function highlight(obj: Object): Void {
		ensureInstalled();
		instance.target = obj;
		instance.visible = true;
		instance.redraw();
	}

	public static function setManualEdit(obj: Null<Object>): Void {
		ensureInstalled();
		if (obj == null) {
			instance.manualEditEnabled = false;
			instance.stopEditingCapture();
			instance.redraw();
			return;
		}
		instance.target = obj;
		instance.manualEditEnabled = true;
		instance.visible = true;
		instance.redraw();
	}

	public static function clear(): Void {
		if (instance == null) return;
		instance.manualEditEnabled = false;
		instance.stopEditingCapture();
		instance.target = null;
		instance.gfx.clear();
		instance.visible = false;
	}

	static function ensureInstalled(): Void {
		if (instance != null) return;
		var app = HeapsDebugServer.getApp();
		instance = new Highlighter();
		app.s2d.addChild(instance);
	}

	override function sync(ctx: h2d.RenderContext) {
		super.sync(ctx);
		var scene = getScene();
		if (scene != null) {
			hitArea.width = scene.width;
			hitArea.height = scene.height;
		}
		if (target == null) return;
		redraw();
	}

	function getTargetBounds(): Bounds {
		if (target == getScene()) {
			var scene = cast target:h2d.Scene;
			bounds = Bounds.fromValues(0, 0, scene.width, scene.height);
		} else {
			bounds = target.getBounds(bounds);
		}
		return bounds;
	}

	function redraw(): Void {
		gfx.clear();
		if (target == null) return;
		getTargetBounds();
		var x = bounds.xMin;
		var y = bounds.yMin;
		var w = bounds.width;
		var h = bounds.height;

		this.x = 0;
		this.y = 0;
		gfx.lineStyle(2, manualEditEnabled ? 0x22CCFF : 0x33FF66, 1.0);
		gfx.drawRect(x, y, w, h);
		if (manualEditEnabled) {
			gfx.beginFill(0x22CCFF, 0.95);
			gfx.drawRect(bounds.xMax - HANDLE_SIZE, bounds.yMax - HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE);
			gfx.endFill();
		}
	}

	function onHitAreaPush(e: Event): Void {
		if (!manualEditEnabled || target == null) return;
		if (e.button != 0) return;
		var mode = getModeAt(e.relX, e.relY);
		if (mode == Idle) return;
		beginEditing(mode, e.relX, e.relY);
		hitArea.startCapture(onCaptureEvent, onCaptureCancelled);
		e.cancel = true;
		e.propagate = false;
	}

	function getModeAt(sceneX: Float, sceneY: Float): ManualEditMode {
		getTargetBounds();
		var isInsideHandle = sceneX >= bounds.xMax - HANDLE_SIZE
			&& sceneX <= bounds.xMax
			&& sceneY >= bounds.yMax - HANDLE_SIZE
			&& sceneY <= bounds.yMax;
		if (isInsideHandle) return Scale;
		var isInsideRect = sceneX >= bounds.xMin
			&& sceneX <= bounds.xMax
			&& sceneY >= bounds.yMin
			&& sceneY <= bounds.yMax;
		if (isInsideRect) return Move;
		return Idle;
	}

	function beginEditing(mode: ManualEditMode, sceneX: Float, sceneY: Float): Void {
		editMode = mode;
		switch (mode) {
			case Idle:
				return;
			case Move:
				var parentPoint = sceneToParent(sceneX, sceneY);
				dragStartPointerParent.x = parentPoint.x;
				dragStartPointerParent.y = parentPoint.y;
				dragStartObjectX = target.x;
				dragStartObjectY = target.y;
			case Scale:
				getTargetBounds();
				dragStartPointerScene.x = sceneX;
				dragStartPointerScene.y = sceneY;
				dragStartObjectX = target.x;
				dragStartObjectY = target.y;
				dragStartBounds.xMin = bounds.xMin;
				dragStartBounds.yMin = bounds.yMin;
				dragStartBounds.xMax = bounds.xMax;
				dragStartBounds.yMax = bounds.yMax;
				dragStartScaleX = target.scaleX;
				dragStartScaleY = target.scaleY;
				var localBounds = target.getBounds(target);
				scaleAnchorLocal.x = localBounds.xMin;
				scaleAnchorLocal.y = localBounds.yMin;
				var anchorParent = localToParent(scaleAnchorLocal.x, scaleAnchorLocal.y);
				scaleAnchorParent.x = anchorParent.x;
				scaleAnchorParent.y = anchorParent.y;
		}
	}

	function onCaptureEvent(e: Event): Void {
		if (!manualEditEnabled || target == null) {
			stopEditingCapture();
			return;
		}
		switch (e.kind) {
			case EMove:
				updateEditing(e.relX, e.relY);
				e.cancel = true;
				e.propagate = false;
			case ERelease, EReleaseOutside:
				updateEditing(e.relX, e.relY);
				stopEditingCapture();
				e.cancel = true;
				e.propagate = false;
			default:
		}
	}

	function onCaptureCancelled(): Void {
		editMode = Idle;
	}

	function stopEditingCapture(): Void {
		if (editMode == Idle) return;
		editMode = Idle;
		hitArea.stopCapture();
	}

	function updateEditing(sceneX: Float, sceneY: Float): Void {
		switch (editMode) {
			case Idle:
				return;
			case Move:
				var parentPoint = sceneToParent(sceneX, sceneY);
				target.x = dragStartObjectX + (parentPoint.x - dragStartPointerParent.x);
				target.y = dragStartObjectY + (parentPoint.y - dragStartPointerParent.y);
			case Scale:
				var startWidth = dragStartBounds.width;
				var startHeight = dragStartBounds.height;
				if (startWidth < EPSILON) startWidth = EPSILON;
				if (startHeight < EPSILON) startHeight = EPSILON;
				var newWidth = Math.max(MIN_SCALE_SIZE, dragStartBounds.width + (sceneX - dragStartPointerScene.x));
				var newHeight = Math.max(MIN_SCALE_SIZE, dragStartBounds.height + (sceneY - dragStartPointerScene.y));
				target.x = dragStartObjectX;
				target.y = dragStartObjectY;
				target.scaleX = dragStartScaleX * (newWidth / startWidth);
				target.scaleY = dragStartScaleY * (newHeight / startHeight);
				var anchorNow = localToParent(scaleAnchorLocal.x, scaleAnchorLocal.y);
				target.x += scaleAnchorParent.x - anchorNow.x;
				target.y += scaleAnchorParent.y - anchorNow.y;
		}
	}

	function sceneToParent(sceneX: Float, sceneY: Float): Point {
		var point = new Point(sceneX, sceneY);
		return target.parent == null ? point : target.parent.globalToLocal(point);
	}

	function localToParent(localX: Float, localY: Float): Point {
		var point = target.localToGlobal(new Point(localX, localY));
		return target.parent == null ? point : target.parent.globalToLocal(point);
	}
}


