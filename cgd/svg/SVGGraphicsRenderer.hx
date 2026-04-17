package cgd.svg;

import cgd.svg.SVGDocument.SVGPathCommand;
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
				
				switch (shape.style.strokeLineCap) {
					case Butt: g.lineCap = Butt;
					case Round: g.lineCap = Round;
					case Square: g.lineCap = Square;
				}
				switch (shape.style.strokeLineJoin) {
					case Miter: g.lineJoin = Miter;
					case Round: g.lineJoin = Round;
					case Bevel: g.lineJoin = Bevel;
				}
				
				if (shape.style.strokeLineJoin == Round || shape.style.strokeLineJoin == Bevel) {
					g.bevel = 1.0;
				} else {
					g.bevel = 1.0 / Math.max(1.0, shape.style.strokeMiterLimit);
				}
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
			
			if (strokeEnabled) {
				drawStrokeCapsAndJoins(g, polyline, shape.style, strokeColor, strokeAlpha);
			}
		}
		g.lineStyle(0);
	}

	function drawStrokeCapsAndJoins(g:Graphics, polyline:SVGPolyline, style:cgd.svg.SVGDocument.SVGNodeStyle, color:Int, alpha:Float):Void {
		var isRoundCap = style.strokeLineCap == Round;
		var isSquareCap = style.strokeLineCap == Square;
		var isRoundJoin = style.strokeLineJoin == Round;
		
		if (!isRoundCap && !isSquareCap && !isRoundJoin) return;
		
		var radius = (style.strokeWidth * unitSize) / 2;
		if (radius <= 0) return;
		
		var pts = polyline.points;
		var n = pts.length;
		if (n == 0) return;

		// Draw caps
		if (!polyline.closed && n > 1) {
			if (isRoundCap) {
				g.lineStyle(0);
				g.beginFill(color, alpha);
				g.drawCircle(pts[0].x * unitSize, pts[0].y * unitSize, radius);
				g.drawCircle(pts[n - 1].x * unitSize, pts[n - 1].y * unitSize, radius);
				g.endFill();
			} else if (isSquareCap) {
				g.lineStyle(style.strokeWidth * unitSize, color, alpha);
				var p0 = pts[0];
				var p1 = pts[1];
				var dx = p0.x - p1.x;
				var dy = p0.y - p1.y;
				var len = Math.sqrt(dx * dx + dy * dy);
				if (len > 0) {
					dx /= len;
					dy /= len;
					g.moveTo(p0.x * unitSize, p0.y * unitSize);
					g.lineTo((p0.x + dx * (radius / unitSize)) * unitSize, (p0.y + dy * (radius / unitSize)) * unitSize);
				}
				var pLast = pts[n - 1];
				var pPrev = pts[n - 2];
				var dx2 = pLast.x - pPrev.x;
				var dy2 = pLast.y - pPrev.y;
				var len2 = Math.sqrt(dx2 * dx2 + dy2 * dy2);
				if (len2 > 0) {
					dx2 /= len2;
					dy2 /= len2;
					g.moveTo(pLast.x * unitSize, pLast.y * unitSize);
					g.lineTo((pLast.x + dx2 * (radius / unitSize)) * unitSize, (pLast.y + dy2 * (radius / unitSize)) * unitSize);
				}
				g.lineStyle(0);
			}
		}

		// Draw round joins
		if (isRoundJoin && n > 2) {
			g.lineStyle(0);
			g.beginFill(color, alpha);
			if (polyline.commands != null) {
				for (i in 1...polyline.commands.length) {
					var cmd = polyline.commands[i];
					switch (cmd) {
						case Move(x, y):
						case Line(x, y): g.drawCircle(x * unitSize, y * unitSize, radius);
						case Cubic(_, _, _, _, x, y): g.drawCircle(x * unitSize, y * unitSize, radius);
					}
				}
				if (polyline.closed && polyline.commands.length > 1) {
					var first = polyline.commands[0];
					switch (first) {
						case Move(x, y): g.drawCircle(x * unitSize, y * unitSize, radius);
						default:
					}
				}
			}
			g.endFill();
		}
	}

	function drawPolyline(g:Graphics, polyline:SVGPolyline):Void {
		if (polyline.commands != null && polyline.commands.length > 0) {
			for (cmd in polyline.commands) {
				switch (cmd) {
					case Move(x, y):
						g.moveTo(x * unitSize, y * unitSize);
					case Line(x, y):
						g.lineTo(x * unitSize, y * unitSize);
					case Cubic(cx1, cy1, cx2, cy2, x, y):
						g.cubicCurveTo(cx1 * unitSize, cy1 * unitSize, cx2 * unitSize, cy2 * unitSize, x * unitSize, y * unitSize);
				}
			}
			if (polyline.closed) {
				var last = polyline.points[polyline.points.length - 1];
				var first = polyline.points[0];
				if (!samePoint(last, first)) {
					g.lineTo(first.x * unitSize, first.y * unitSize);
				}
			}
			return;
		}

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
