package cgd.svg;

import cgd.svg.SVGDocument.SVGRenderStats;
import cgd.svg.SVGMeshRenderer.SVGMeshDrawable;
import h2d.Graphics;

using StringTools;

enum SVGRenderMode {
	PathRendering;
	MeshRendering;
}

private typedef HiddenObjectState = {
	var obj:h2d.Object;
	var visible:Bool;
}

class SVG extends h2d.Object {
	public var graphics(default, null):Null<Graphics>;
	public var meshDrawable(default, null):Null<SVGMeshDrawable>;
	public var bakedBitmap(default, null):Null<h2d.Bitmap>;
	public var parser(default, null):SVGParser;
	public var renderer(default, null):SVGGraphicsRenderer;
	public var meshRenderer(default, null):SVGMeshRenderer;
	public var document(default, null):Null<SVGDocument>;
	public var currentColor(get, set):Int;
	public var unitSize(get, set):Int;
	public var source(get, set):Null<String>;
	public var renderMode(get, set):SVGRenderMode;
	public var lastStats(default, null):Null<SVGRenderStats>;
	public var contentWidth(get, never):Float;
	public var contentHeight(get, never):Float;

	var svgSource:Null<String> = null;
	var svgCurrentColor:Int = 0xFFFFFF;
	var svgUnitSize:Int = 1;
	var svgRenderMode:SVGRenderMode = PathRendering;

	public function new(?source:String, ?parent:h2d.Object) {
		super(parent);
		parser = new SVGParser();
		renderer = new SVGGraphicsRenderer();
		meshRenderer = new SVGMeshRenderer();
		parser.setCurrentColor(svgCurrentColor);
		renderer.setUnitSize(svgUnitSize);
		meshRenderer.setUnitSize(svgUnitSize);
		if (source != null) {
			load(source);
		}
	}

	public function load(source:String):Void {
		this.source = source;
	}

	public function setSvg(source:String):Void {
		this.source = source;
	}

	public function redraw():Void {
		clearBakedBitmap();
		var source = svgSource;
		if (source == null || source.trim() == "") {
			if (graphics != null)
				graphics.clear();
			if (meshDrawable != null)
				meshDrawable.clear();
			document = null;
			lastStats = null;
			return;
		}

		parser.setCurrentColor(svgCurrentColor);
		if (document == null) {
			document = parser.parse(source);
		}

		switch (svgRenderMode) {
			case MeshRendering:
				if (graphics != null)
					graphics.visible = false;
				meshRenderer.setUnitSize(svgUnitSize);
				var target = ensureMeshDrawable();
				if (target == null) {
					lastStats = meshRenderer.inspect(document);
					return;
				}
				target.visible = true;
				lastStats = meshRenderer.render(document, target);

			case PathRendering:
				if (meshDrawable != null)
					meshDrawable.visible = false;
				renderer.setUnitSize(svgUnitSize);
				var target = ensureGraphics();
				if (target == null) {
					lastStats = renderer.inspect(document);
					return;
				}
				target.visible = true;
				lastStats = renderer.render(document, target);
		}
	}

	public function bake():Null<h2d.Bitmap> {
		if (svgSource == null || svgSource.trim() == "") {
			clearBakedBitmap();
			return null;
		}

		if (document == null || lastStats == null) {
			redraw();
		}

		var bounds = lastStats == null ? null : lastStats.bounds;
		if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
			clearBakedBitmap();
			return null;
		}

		var activeVisual = getActiveVisual();
		if (activeVisual == null) {
			return null;
		}

		var originalVisible = activeVisual.visible;
		var originalBakedVisible = bakedBitmap != null && bakedBitmap.visible;
		var scene = getScene();
		if (scene == null)
			return null;
		if (bakedBitmap != null)
			bakedBitmap.visible = false;
		activeVisual.visible = true;
		var xMin = Math.floor(bounds.x + 1e-10);
		var yMin = Math.floor(bounds.y + 1e-10);
		var textureWidth = Std.int(Math.ceil(bounds.x + bounds.width - xMin - 1e-10));
		var textureHeight = Std.int(Math.ceil(bounds.y + bounds.height - yMin - 1e-10));
		if (textureWidth <= 0 || textureHeight <= 0) {
			activeVisual.visible = originalVisible;
			if (bakedBitmap != null)
				bakedBitmap.visible = originalBakedVisible;
			clearBakedBitmap();
			return null;
		}

		scene.syncOnly(0);
		var absoluteBounds = getBounds();
		var cutX = Math.floor(absoluteBounds.xMin + 1e-10);
		var cutY = Math.floor(absoluteBounds.yMin + 1e-10);
		var hiddenObjects = new Array<HiddenObjectState>();
		var ancestorChain = new haxe.ds.ObjectMap<h2d.Object, Bool>();
		var cursor:h2d.Object = this;
		while (cursor != null) {
			ancestorChain.set(cursor, true);
			cursor = cursor.parent;
		}
		hideSceneOutsideSubtree(scene, ancestorChain, hiddenObjects);
		var engine = h3d.Engine.getCurrent();
		var oldBackgroundColor = engine.backgroundColor;
		engine.backgroundColor = 0;
		var snapshot = scene.captureBitmap();
		engine.backgroundColor = oldBackgroundColor;
		restoreHiddenObjects(hiddenObjects);

		activeVisual.visible = originalVisible;
		if (bakedBitmap != null)
			bakedBitmap.visible = originalBakedVisible;

		clearBakedBitmap();
		var baked = ensureBakedBitmap();
		var pixels = snapshot.tile.getTexture().capturePixels();
		var clipX = cutX < 0 ? 0 : cutX;
		var clipY = cutY < 0 ? 0 : cutY;
		var clipWidth = textureWidth;
		var clipHeight = textureHeight;
		if (clipX + clipWidth > pixels.width)
			clipWidth = pixels.width - clipX;
		if (clipY + clipHeight > pixels.height)
			clipHeight = pixels.height - clipY;
		if (clipWidth <= 0 || clipHeight <= 0)
			return null;
		var croppedPixels = pixels.sub(clipX, clipY, clipWidth, clipHeight);
		for (py in 0...croppedPixels.height) {
			for (px in 0...croppedPixels.width) {
				if (croppedPixels.getPixel(px, py) == 0xFF000000) {
					croppedPixels.setPixel(px, py, 0x00000000);
				}
			}
		}
		var tile = h2d.Tile.fromPixels(croppedPixels);
		tile.dx = xMin + (clipX - cutX);
		tile.dy = yMin + (clipY - cutY);
		baked.tile = tile;
		baked.x = 0;
		baked.y = 0;
		baked.visible = true;

		if (graphics != null)
			graphics.visible = false;
		if (meshDrawable != null)
			meshDrawable.visible = false;

		return baked;
	}

	public function clear():Void {
		svgSource = null;
		document = null;
		lastStats = null;
		clearBakedBitmap();
		if (graphics != null)
			graphics.clear();
		if (meshDrawable != null)
			meshDrawable.clear();
	}

	override function onAdd() {
		super.onAdd();
		if (svgSource == null)
			return;
		switch (svgRenderMode) {
			case PathRendering:
				if (graphics == null)
					redraw();
			case MeshRendering:
				if (meshDrawable == null)
					redraw();
		}
	}

	function get_currentColor():Int {
		return svgCurrentColor;
	}

	function set_currentColor(value:Int):Int {
		svgCurrentColor = value;
		document = null;
		if (svgSource != null) {
			redraw();
		}
		return value;
	}

	function get_unitSize():Int {
		return svgUnitSize;
	}

	function set_unitSize(value:Int):Int {
		svgUnitSize = value;
		if (svgSource != null) {
			redraw();
		}
		return value;
	}

	function get_source():Null<String> {
		return svgSource;
	}

	function set_source(value:Null<String>):Null<String> {
		svgSource = value;
		document = null;
		redraw();
		return value;
	}

	function get_renderMode():SVGRenderMode {
		return svgRenderMode;
	}

	function set_renderMode(value:SVGRenderMode):SVGRenderMode {
		svgRenderMode = value;
		if (svgSource != null) {
			redraw();
		}
		return value;
	}

	function get_contentWidth():Float {
		return lastStats == null || lastStats.bounds == null ? 0 : lastStats.bounds.width;
	}

	function get_contentHeight():Float {
		return lastStats == null || lastStats.bounds == null ? 0 : lastStats.bounds.height;
	}

	function ensureGraphics():Null<Graphics> {
		if (graphics != null)
			return graphics;
		if (h3d.Engine.getCurrent() == null)
			return null;
		graphics = new Graphics(this);
		return graphics;
	}

	function ensureMeshDrawable():Null<SVGMeshDrawable> {
		if (meshDrawable != null)
			return meshDrawable;
		if (h3d.Engine.getCurrent() == null)
			return null;
		meshDrawable = new SVGMeshDrawable(this);
		return meshDrawable;
	}

	function getActiveVisual():Null<h2d.Object> {
		return switch (svgRenderMode) {
			case PathRendering:
				ensureGraphics();
			case MeshRendering:
				ensureMeshDrawable();
		}
	}

	function ensureBakedBitmap():h2d.Bitmap {
		if (bakedBitmap == null) {
			bakedBitmap = new h2d.Bitmap(null, this);
			bakedBitmap.visible = false;
		}
		return bakedBitmap;
	}

	function clearBakedBitmap():Void {
		if (bakedBitmap == null)
			return;
		if (bakedBitmap.tile != null)
			bakedBitmap.tile.dispose();
		bakedBitmap.tile = null;
		bakedBitmap.visible = false;
	}

	function hideSceneOutsideSubtree(root:h2d.Object, ancestorChain:haxe.ds.ObjectMap<h2d.Object, Bool>, hiddenObjects:Array<HiddenObjectState>):Void {
		if (root == this)
			return;
		for (i in 0...root.numChildren) {
			var child = root.getChildAt(i);
			if (ancestorChain.exists(child)) {
				hideSceneOutsideSubtree(child, ancestorChain, hiddenObjects);
			} else {
				hiddenObjects.push({obj: child, visible: child.visible});
				child.visible = false;
			}
		}
	}

	function restoreHiddenObjects(hiddenObjects:Array<HiddenObjectState>):Void {
		for (state in hiddenObjects) {
			state.obj.visible = state.visible;
		}
	}
}
