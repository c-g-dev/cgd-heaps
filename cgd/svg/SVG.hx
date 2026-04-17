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

	public function clear():Void {
		svgSource = null;
		document = null;
		lastStats = null;
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
}
