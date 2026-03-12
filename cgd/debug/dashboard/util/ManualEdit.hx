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

	var moveOffsetX:Float = 0;
	var moveOffsetY:Float = 0;

	var dragStartScaleX:Float = 1;
	var dragStartScaleY:Float = 1;
	var dragStartV:Point;

	var dragOriginX:Float = 0;
	var dragOriginY:Float = 0;
	var dragStartRotation:Float = 0;
	var dragStartAngle:Float = 0;

	static inline var HANDLE_SIZE:Float = 8;
	static inline var ROTATE_OFFSET:Float = 30;
	static inline var HIT_RADIUS:Float = 12;

	public function new() {
		super();
		gfx = new Graphics(this);
		mode = MODE_IDLE;
		overlay = new Interactive(1, 1, this);
		overlay.cursor = Default;
		overlay.onPush = function(e:hxd.Event) {
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
		var scene = target.getScene();
		if (scene == null) scene = HeapsDebugServer.getApp().s2d;
		var bounds = target.getBounds(scene);

		var rcx = (bounds.xMin + bounds.xMax) * 0.5;
		var rcy = bounds.yMin - ROTATE_OFFSET;
		var hitRadius2 = HIT_RADIUS * HIT_RADIUS;

		if (distSq(mx, my, rcx, rcy) < hitRadius2) {
			mode = MODE_ROTATE;
			var origin = target.localToGlobal(new Point(0, 0));
			dragOriginX = origin.x;
			dragOriginY = origin.y;
			dragStartRotation = target.rotation;
			dragStartAngle = Math.atan2(my - dragOriginY, mx - dragOriginX);
			return;
		}

		if (distSq(mx, my, bounds.xMin, bounds.yMin) < hitRadius2
			|| distSq(mx, my, bounds.xMax, bounds.yMin) < hitRadius2
			|| distSq(mx, my, bounds.xMin, bounds.yMax) < hitRadius2
			|| distSq(mx, my, bounds.xMax, bounds.yMax) < hitRadius2) {
			mode = MODE_SCALE;
			dragStartScaleX = target.scaleX;
			dragStartScaleY = target.scaleY;
			dragStartV = getLocalVec(mx, my);
			return;
		}

		if (mx >= bounds.xMin && mx <= bounds.xMax && my >= bounds.yMin && my <= bounds.yMax) {
			mode = MODE_MOVE;
			if (target.parent != null) {
				var parentLocal = target.parent.globalToLocal(new Point(mx, my));
				moveOffsetX = target.x - parentLocal.x;
				moveOffsetY = target.y - parentLocal.y;
			} else {
				moveOffsetX = target.x - mx;
				moveOffsetY = target.y - my;
			}
			return;
		}
	}

	function handleDrag(mx:Float, my:Float):Void {
		if (target == null || mode == MODE_IDLE) return;

		if (mode == MODE_MOVE) {
			if (target.parent != null) {
				var parentLocal = target.parent.globalToLocal(new Point(mx, my));
				target.x = parentLocal.x + moveOffsetX;
				target.y = parentLocal.y + moveOffsetY;
			} else {
				target.x = mx + moveOffsetX;
				target.y = my + moveOffsetY;
			}
		} else if (mode == MODE_SCALE) {
			var curV = getLocalVec(mx, my);
			// Avoid division by zero
			if (Math.abs(dragStartV.x) > 1e-5) 
				target.scaleX = dragStartScaleX * (curV.x / dragStartV.x);
			if (Math.abs(dragStartV.y) > 1e-5) 
				target.scaleY = dragStartScaleY * (curV.y / dragStartV.y);
		} else if (mode == MODE_ROTATE) {
			var curAngle = Math.atan2(my - dragOriginY, mx - dragOriginX);
			target.rotation = dragStartRotation + (curAngle - dragStartAngle);
		}
	}

	function getLocalVec(mx:Float, my:Float):Point {
		var p = new Point(mx, my);
		if (target.parent != null) {
			p = target.parent.globalToLocal(p);
		}
		var dx = p.x - target.x;
		var dy = p.y - target.y;
		
		// De-rotate by target rotation to align with local axes
		var r = -target.rotation;
		var c = Math.cos(r);
		var s = Math.sin(r);
		
		return new Point(dx * c - dy * s, dx * s + dy * c);
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

		var scene = target.getScene();
		if (scene == null) scene = HeapsDebugServer.getApp().s2d;
		var bounds = target.getBounds(scene);

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
