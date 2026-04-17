package cgd.debug.dashboard.util;

import cgd.debug.dashboard.HeapsDebugServer;
import h2d.Graphics;
import h2d.Interactive;
import h2d.Object;
import h2d.col.Bounds;
import h2d.col.Point;

class ManualEdit extends h2d.Object {
	static var instance:ManualEdit;

	var target:Object;
	var gfx:Graphics;
	var overlay:Interactive;
	var mode:Int;

	static inline var MODE_IDLE = 0;
	static inline var MODE_MOVE = 1;
	static inline var MODE_SCALE = 2;
	static inline var MODE_ROTATE = 3;

	var lastDragX:Float = 0;
	var lastDragY:Float = 0;
	var dragStartScaleX:Float = 1;
	var dragStartScaleY:Float = 1;
	var dragStartRotation:Float = 0;
	var dragStartAngle:Float = 0;
	var dragOriginX:Float = 0;
	var dragOriginY:Float = 0;
	var dragCornerDx:Float = 0;
	var dragCornerDy:Float = 0;
	var dragHandleOffsetX:Float = 0;
	var dragHandleOffsetY:Float = 0;

	static inline var HANDLE_SIZE:Float = 8;
	static inline var HANDLE_HIT:Float = 10;
	static inline var ROTATE_OFFSET:Float = 30;
	static inline var ROTATE_HIT:Float = 12;

	public function new() {
		super();
		gfx = new Graphics(this);
		mode = MODE_IDLE;
		overlay = new Interactive(1, 1, this);
		overlay.cursor = Default;
		overlay.onPush = function(e:hxd.Event) {
			trace('push: ${e.relX}, ${e.relY}');
			handlePush(e.relX, e.relY);
		};
		overlay.onRelease = function(e:hxd.Event) {
			mode = MODE_IDLE;
		};
		overlay.onReleaseOutside = function(e:hxd.Event) {
			mode = MODE_IDLE;
		};
		overlay.onMove = function(e:hxd.Event) {
			handleDrag(e.relX, e.relY);
		};
	}

	public static function setTarget(obj:Object):Void {
		ensureInstalled();
		instance.target = obj;
		instance.mode = MODE_IDLE;
		instance.visible = obj != null;
		if (obj != null)
			instance.redraw();
		else
			instance.gfx.clear();
	}

	public static function getTarget():Object {
		return instance == null ? null : instance.target;
	}

	static function ensureInstalled():Void {
		if (instance != null) return;
		var app = HeapsDebugServer.getApp();
		instance = new ManualEdit();
		app.s2d.addChild(instance);
	}

	function handlePush(mx:Float, my:Float):Void {
		if (target == null) return;
		var bounds = target.getBounds();

		var rcx = (bounds.xMin + bounds.xMax) * 0.5;
		var rcy = bounds.yMin - ROTATE_OFFSET;
		if (distSq(mx, my, rcx, rcy) < ROTATE_HIT * ROTATE_HIT) {
			mode = MODE_ROTATE;
			var origin = target.localToGlobal(new Point(0, 0));
			dragOriginX = origin.x;
			dragOriginY = origin.y;
			dragStartRotation = target.rotation;
			dragStartAngle = Math.atan2(my - dragOriginY, mx - dragOriginX);
			return;
		}

		var cornerX:Float = 0;
		var cornerY:Float = 0;
		var hitCorner = false;
		var hh = HANDLE_HIT;

		if (Math.abs(mx - bounds.xMin) < hh && Math.abs(my - bounds.yMin) < hh) {
			cornerX = bounds.xMin;
			cornerY = bounds.yMin;
			hitCorner = true;
		} else if (Math.abs(mx - bounds.xMax) < hh && Math.abs(my - bounds.yMin) < hh) {
			cornerX = bounds.xMax;
			cornerY = bounds.yMin;
			hitCorner = true;
		} else if (Math.abs(mx - bounds.xMin) < hh && Math.abs(my - bounds.yMax) < hh) {
			cornerX = bounds.xMin;
			cornerY = bounds.yMax;
			hitCorner = true;
		} else if (Math.abs(mx - bounds.xMax) < hh && Math.abs(my - bounds.yMax) < hh) {
			cornerX = bounds.xMax;
			cornerY = bounds.yMax;
			hitCorner = true;
		}

		if (hitCorner) {
			mode = MODE_SCALE;
			var origin = target.localToGlobal(new Point(0, 0));
			dragOriginX = origin.x;
			dragOriginY = origin.y;
			dragCornerDx = cornerX - dragOriginX;
			dragCornerDy = cornerY - dragOriginY;
			dragHandleOffsetX = mx - cornerX;
			dragHandleOffsetY = my - cornerY;
			dragStartScaleX = target.scaleX;
			dragStartScaleY = target.scaleY;
			return;
		}

		trace('check move bounds: ${bounds.xMin}, ${bounds.xMax}, ${bounds.yMin}, ${bounds.yMax}');
		if (mx >= bounds.xMin && mx <= bounds.xMax && my >= bounds.yMin && my <= bounds.yMax) {
			mode = MODE_MOVE;
			lastDragX = mx;
			lastDragY = my;
			return;
		}
	}

	function handleDrag(mx:Float, my:Float):Void {
		if (target == null || mode == MODE_IDLE) return;

		if (mode == MODE_MOVE) {
			trace('move: ${mx}, ${my} ${lastDragX}, ${lastDragY}');
			var dx = mx - lastDragX;
			var dy = my - lastDragY;
			lastDragX = mx;
			lastDragY = my;
			if (target.parent != null) {
				var a = target.parent.globalToLocal(new Point(0, 0));
				var b = target.parent.globalToLocal(new Point(dx, dy));
				trace('move: ${dx}, ${dy} ${a.x}, ${a.y} ${b.x}, ${b.y}');
				target.x += b.x - a.x;
				target.y += b.y - a.y;
			} else {
				target.x += dx;
				target.y += dy;
			}
		} else if (mode == MODE_SCALE) {
			var effectiveX = mx - dragHandleOffsetX - dragOriginX;
			var effectiveY = my - dragHandleOffsetY - dragOriginY;
			if (Math.abs(dragCornerDx) > 1) target.scaleX = dragStartScaleX * (effectiveX / dragCornerDx);
			if (Math.abs(dragCornerDy) > 1) target.scaleY = dragStartScaleY * (effectiveY / dragCornerDy);
		} else if (mode == MODE_ROTATE) {
			var curAngle = Math.atan2(my - dragOriginY, mx - dragOriginX);
			target.rotation = dragStartRotation + (curAngle - dragStartAngle);
		}
	}

	static inline function distSq(x1:Float, y1:Float, x2:Float, y2:Float):Float {
		return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);
		if (target == null) return;
		var scene = this.getScene();
		if (scene != null) {
			overlay.width = scene.width;
			overlay.height = scene.height;
		}
		redraw();
	}

	function redraw():Void {
		if (target == null) return;

		var bounds:Bounds;
		if (target == this.getScene()) {
			var scene:h2d.Scene = cast target;
			bounds = Bounds.fromValues(0, 0, scene.width, scene.height);
		} else {
			bounds = target.getBounds();
		}

		gfx.clear();
		this.x = 0;
		this.y = 0;

		var bx = bounds.xMin;
		var by = bounds.yMin;
		var bw = bounds.width;
		var bh = bounds.height;
		var hs = HANDLE_SIZE;

		gfx.lineStyle(2, 0x00BFFF, 1.0);
		gfx.drawRect(bx, by, bw, bh);

		gfx.lineStyle();
		gfx.beginFill(0x00BFFF, 0.9);
		gfx.drawRect(bx - hs * 0.5, by - hs * 0.5, hs, hs);
		gfx.drawRect(bx + bw - hs * 0.5, by - hs * 0.5, hs, hs);
		gfx.drawRect(bx - hs * 0.5, by + bh - hs * 0.5, hs, hs);
		gfx.drawRect(bx + bw - hs * 0.5, by + bh - hs * 0.5, hs, hs);
		gfx.endFill();

		var rcx = bx + bw * 0.5;
		var rcy = by - ROTATE_OFFSET;
		gfx.lineStyle(1, 0xFF8C00, 1.0);
		gfx.moveTo(bx + bw * 0.5, by);
		gfx.lineTo(rcx, rcy);
		gfx.lineStyle();
		gfx.beginFill(0xFF8C00, 0.9);
		gfx.drawCircle(rcx, rcy, 5);
		gfx.endFill();
	}
}
