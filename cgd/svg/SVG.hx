package cgd.svg;

import cgd.svg.SVGDocument.SVGRenderStats;
import cgd.svg.SVGMeshRenderer.SVGMeshDrawable;
import h2d.Graphics;

using StringTools;

enum SVGRenderMode {
	PathRendering;
	MeshRendering;
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

	public function bake():Void {
		var bounds = this.getBounds(this);
		var w = Math.ceil(bounds.width);
		var h = Math.ceil(bounds.height);
		if (w <= 0 || h <= 0) return;

		var tex = new h3d.mat.Texture(w, h, [Target]);
		tex.clear(0, 0);

		var tempContainer = new h2d.Object();
		tempContainer.x = -bounds.xMin;
		tempContainer.y = -bounds.yMin;

		var hasGraphics = graphics != null && graphics.visible;
		var hasMesh = meshDrawable != null && meshDrawable.visible;

		if (hasGraphics) tempContainer.addChild(graphics);
		if (hasMesh) tempContainer.addChild(meshDrawable);

		tempContainer.drawTo(tex);

		if (hasGraphics) {
			addChild(graphics);
			graphics.visible = false;
		}
		if (hasMesh) {
			addChild(meshDrawable);
			meshDrawable.visible = false;
		}

		if (bakedBitmap != null) {
			var t = bakedBitmap.tile;
			if (t != null && t.getTexture() != null) {
				t.getTexture().dispose();
			}
			bakedBitmap.remove();
		}

		var tile = h2d.Tile.fromTexture(tex);
		tile.dx = bounds.xMin;
		tile.dy = bounds.yMin;

		bakedBitmap = new h2d.Bitmap(tile, this);

		//this.source = null;
	}

	public function clear():Void {
		svgSource = null;
		document = null;
		lastStats = null;
		if (graphics != null)
			graphics.clear();
		if (meshDrawable != null)
			meshDrawable.clear();
		if (bakedBitmap != null) {
			var t = bakedBitmap.tile;
			if (t != null && t.getTexture() != null) {
				t.getTexture().dispose();
			}
			bakedBitmap.remove();
			bakedBitmap = null;
		}
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
		if (value != null && bakedBitmap != null) {
			var t = bakedBitmap.tile;
			if (t != null && t.getTexture() != null) {
				t.getTexture().dispose();
			}
			bakedBitmap.remove();
			bakedBitmap = null;
		}
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
		if (lastStats != null && lastStats.bounds != null) return lastStats.bounds.width;
		if (bakedBitmap != null && bakedBitmap.tile != null) return bakedBitmap.tile.width;
		return 0;
	}

	function get_contentHeight():Float {
		if (lastStats != null && lastStats.bounds != null) return lastStats.bounds.height;
		if (bakedBitmap != null && bakedBitmap.tile != null) return bakedBitmap.tile.height;
		return 0;
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
}
