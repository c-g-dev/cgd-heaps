package cgd.svg;

import cgd.svg.SVGDocument.SVGPolyline;
import cgd.svg.SVGDocument.SVGRenderStats;
import cgd.svg.SVGDocument.SVGShape;
import h2d.Graphics;

class SVGGraphicsRenderer {
	public var lastStats(default, null):Null<SVGRenderStats>;

	var unitSize:Int = 1;

	public function new() {}

	public function setUnitSize(unitSize:Int) {
		this.unitSize = unitSize;
	}

	public function inspect(document:SVGDocument):SVGRenderStats {
		return SVGDocument.scaleStats(document.stats, unitSize);
	}

	public function render(document:SVGDocument, g:Graphics):SVGRenderStats {
		var stats = inspect(document);
		lastStats = stats;
		g.clear();
		for (shape in document.shapes) {
			drawShape(g, shape);
		}
		return stats;
	}

	public function drawRoundedRect(graphics:Graphics, x:Float, y:Float, w:Float, h:Float, radius:Float, nsegments = 0) {
		var polyline = SVGParser.createRoundedRectPolyline(x, y, w, h, radius, radius, nsegments);
		drawPolyline(graphics, polyline);
	}

	public function drawArc(graphics:Graphics, x0:Float, y0:Float, rx:Float, ry:Float, xAxisRotation:Float, largeArcFlag:Int, sweepFlag:Int, dx:Float, dy:Float) {
		var polyline = SVGParser.createArcPolyline(x0, y0, rx, ry, xAxisRotation, largeArcFlag, sweepFlag, dx, dy);
		drawPolyline(graphics, polyline);
	}

	function drawShape(g:Graphics, shape:SVGShape):Void {
		var strokeEnabled = shape.style.stroke != null && shape.style.strokeWidth > 0;
		var strokeColor = strokeEnabled ? shape.style.stroke : 0;
		var strokeAlpha = shape.style.opacity * shape.style.strokeOpacity;
		var fillAlpha = shape.style.opacity * shape.style.fillOpacity;

		for (polyline in shape.polylines) {
			var fillEnabled = shape.style.fill != null && polyline.closed;
			if (strokeEnabled) {
				g.lineStyle(shape.style.strokeWidth * unitSize, strokeColor, strokeAlpha);
			} else {
				g.lineStyle(0);
			}
			if (fillEnabled) {
				g.beginFill(shape.style.fill, fillAlpha);
			}
			drawPolyline(g, polyline);
			if (fillEnabled) {
				g.endFill();
			}
		}
		g.lineStyle(0);
	}

	function drawPolyline(g:Graphics, polyline:SVGPolyline):Void {
		if (polyline.points.length == 0) {
			return;
		}

		var first = polyline.points[0];
		g.moveTo(first.x * unitSize, first.y * unitSize);
		for (i in 1...polyline.points.length) {
			var pt = polyline.points[i];
			g.lineTo(pt.x * unitSize, pt.y * unitSize);
		}

		if (polyline.closed) {
			var last = polyline.points[polyline.points.length - 1];
			if (!samePoint(last, first)) {
				g.lineTo(first.x * unitSize, first.y * unitSize);
			}
		}
	}

	function samePoint(a:{x:Float, y:Float}, b:{x:Float, y:Float}):Bool {
		var dx = b.x - a.x;
		var dy = b.y - a.y;
		return dx * dx + dy * dy <= 1e-9;
	}
}
