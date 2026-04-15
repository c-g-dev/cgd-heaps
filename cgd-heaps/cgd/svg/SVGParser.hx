package cgd.svg;

import cgd.svg.SVGDocument.SVGFillRule;
import cgd.svg.SVGDocument.SVGNodeStyle;
import cgd.svg.SVGDocument.SVGPoint;
import cgd.svg.SVGDocument.SVGPolyline;
import cgd.svg.SVGDocument.SVGRenderStats;
import cgd.svg.SVGDocument.SVGShape;
import cgd.svg.SVGDocument.SVGStrokeLineCap;
import cgd.svg.SVGDocument.SVGStrokeLineJoin;
import h2d.col.Matrix;
import haxe.xml.Parser;

using StringTools;

private typedef SVGPaintResult = {
	var color:Null<Int>;
	var usedCurrentColor:Bool;
}

class SVGParser {
	public var currentColor(default, null):Int = 0xFFFFFF;

	public function new() {}

	public function setCurrentColor(currentColor:Int) {
		this.currentColor = currentColor;
	}

	public function inspect(svgString:String):SVGRenderStats {
		return parse(svgString).stats;
	}

	public function parse(svgString:String):SVGDocument {
		return buildDocument(svgString);
	}

	public static function createArcPolyline(
		x0:Float,
		y0:Float,
		rx:Float,
		ry:Float,
		xAxisRotation:Float,
		largeArcFlag:Int,
		sweepFlag:Int,
		dx:Float,
		dy:Float
	):SVGPolyline {
		var start = point(x0, y0);
		var points = [start];
		appendArcPoints(points, start, rx, ry, xAxisRotation, largeArcFlag != 0, sweepFlag != 0, point(x0 + dx, y0 + dy));
		return {
			points: points,
			closed: false
		};
	}

	public static function createRoundedRectPolyline(
		x:Float,
		y:Float,
		width:Float,
		height:Float,
		rxValue:Float,
		ryValue:Float,
		?segments:Int
	):SVGPolyline {
		var rx = hxd.Math.clamp(Math.abs(rxValue), 0, width * 0.5);
		var ry = hxd.Math.clamp(Math.abs(ryValue), 0, height * 0.5);
		if (rx == 0 || ry == 0) {
			return {
				points: [
					point(x, y),
					point(x + width, y),
					point(x + width, y + height),
					point(x, y + height)
				],
				closed: true
			};
		}

		var count = segments == null ? Std.int(Math.ceil(Math.max(rx, ry) * Math.PI / 4)) : segments;
		if (count < 4) {
			count = 4;
		}

		var points:Array<SVGPoint> = [];
		appendEllipseArc(points, x + width - rx, y + ry, rx, ry, -Math.PI * 0.5, 0, count, true);
		appendEllipseArc(points, x + width - rx, y + height - ry, rx, ry, 0, Math.PI * 0.5, count, false);
		appendEllipseArc(points, x + rx, y + height - ry, rx, ry, Math.PI * 0.5, Math.PI, count, false);
		appendEllipseArc(points, x + rx, y + ry, rx, ry, Math.PI, Math.PI * 1.5, count, false);
		return {
			points: points,
			closed: true
		};
	}

	function buildDocument(svgString:String):SVGDocument {
		var stats = SVGDocument.createEmptyStats();
		var xml = Parser.parse(svgString);
		var svgTag = xml.firstElement();
		var defaultStyle = createDefaultStyle();
		var rootStyle = resolveStyle(svgTag, defaultStyle, stats);
		var rootTransform = buildRootTransform(svgTag);
		rootTransform = appendMatrix(rootTransform, parseTransform(svgTag.get("transform")));
		var shapes:Array<SVGShape> = [];
		renderChildren(svgTag, rootStyle, rootTransform, shapes, stats);
		return new SVGDocument(shapes, stats);
	}

	function renderChildren(parent:Xml, inheritedStyle:SVGNodeStyle, inheritedTransform:Matrix, shapes:Array<SVGShape>, stats:SVGRenderStats):Void {
		for (child in parent.elements()) {
			renderNode(child, inheritedStyle, inheritedTransform, shapes, stats);
		}
	}

	function renderNode(node:Xml, inheritedStyle:SVGNodeStyle, inheritedTransform:Matrix, shapes:Array<SVGShape>, stats:SVGRenderStats):Void {
		if (node.nodeType != Xml.Element) {
			return;
		}

		var tagName = node.nodeName;
		if (tagName == "defs") {
			return;
		}

		stats.nodeCount++;

		var style = resolveStyle(node, inheritedStyle, stats);
		var transform = appendMatrix(inheritedTransform, parseTransform(node.get("transform")));

		switch (tagName) {
			case "g", "svg":
				renderChildren(node, style, transform, shapes, stats);
			case "path":
				var d = node.get("d");
				if (d != null) {
					addShape(parsePathData(d), style, transform, shapes, stats);
				}
			case "rect":
				var width = parseNumber(node.get("width"), 0);
				var height = parseNumber(node.get("height"), 0);
				if (width > 0 && height > 0) {
					var x = parseNumber(node.get("x"), 0);
					var y = parseNumber(node.get("y"), 0);
					var rx = parseOptionalNumber(node.get("rx"));
					var ry = parseOptionalNumber(node.get("ry"));
					var radiusX = rx == null ? (ry == null ? 0 : ry) : rx;
					var radiusY = ry == null ? radiusX : ry;
					var polyline = createRoundedRectPolyline(x, y, width, height, radiusX, radiusY);
					addShape([polyline], style, transform, shapes, stats);
				}
			case "circle":
				var r = parseNumber(node.get("r"), 0);
				if (r > 0) {
					var cx = parseNumber(node.get("cx"), 0);
					var cy = parseNumber(node.get("cy"), 0);
					addShape([createEllipsePolyline(cx, cy, r, r)], style, transform, shapes, stats);
				}
			case "ellipse":
				var rx = parseNumber(node.get("rx"), 0);
				var ry = parseNumber(node.get("ry"), 0);
				if (rx > 0 && ry > 0) {
					var cx = parseNumber(node.get("cx"), 0);
					var cy = parseNumber(node.get("cy"), 0);
					addShape([createEllipsePolyline(cx, cy, rx, ry)], style, transform, shapes, stats);
				}
			case "line":
				addShape([{
					points: [
						point(parseNumber(node.get("x1"), 0), parseNumber(node.get("y1"), 0)),
						point(parseNumber(node.get("x2"), 0), parseNumber(node.get("y2"), 0))
					],
					closed: false
				}], style, transform, shapes, stats);
			case "polyline":
				var points = parsePoints(node.get("points"));
				if (points.length > 1) {
					addShape([{points: points, closed: false}], style, transform, shapes, stats);
				}
			case "polygon":
				var points = parsePoints(node.get("points"));
				if (points.length > 2) {
					addShape([{points: points, closed: true}], style, transform, shapes, stats);
				}
			default:
		}
	}

	function addShape(polylines:Array<SVGPolyline>, style:SVGNodeStyle, transform:Matrix, shapes:Array<SVGShape>, stats:SVGRenderStats):Void {
		var transformedPolylines:Array<SVGPolyline> = [];
		for (polyline in polylines) {
			if (polyline.points.length == 0) {
				continue;
			}
			var transformed = transformPolyline(polyline, transform);
			if (transformed.points.length == 0) {
				continue;
			}
			transformedPolylines.push(transformed);
		}

		if (transformedPolylines.length == 0) {
			return;
		}

		var shape:SVGShape = {
			polylines: transformedPolylines,
			style: SVGDocument.cloneStyle(style)
		};
		shapes.push(shape);

		stats.shapeCount++;
		stats.subpathCount += transformedPolylines.length;

		var hasClosedPath = false;
		for (polyline in transformedPolylines) {
			if (polyline.closed) {
				hasClosedPath = true;
			}
		}
		if (shape.style.fill != null && hasClosedPath) {
			stats.filledShapeCount++;
		}
		if (shape.style.stroke != null && shape.style.strokeWidth > 0) {
			stats.strokedShapeCount++;
		}

		updateBounds(stats, shape);
	}

	function updateBounds(stats:SVGRenderStats, shape:SVGShape):Void {
		var minX = Math.POSITIVE_INFINITY;
		var minY = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY;
		var maxY = Math.NEGATIVE_INFINITY;

		for (polyline in shape.polylines) {
			for (pt in polyline.points) {
				if (pt.x < minX) minX = pt.x;
				if (pt.y < minY) minY = pt.y;
				if (pt.x > maxX) maxX = pt.x;
				if (pt.y > maxY) maxY = pt.y;
			}
		}

		if (!Math.isFinite(minX) || !Math.isFinite(minY) || !Math.isFinite(maxX) || !Math.isFinite(maxY)) {
			return;
		}

		var halfStroke = shape.style.stroke != null && shape.style.strokeWidth > 0 ? shape.style.strokeWidth * 0.5 : 0.0;
		minX -= halfStroke;
		minY -= halfStroke;
		maxX += halfStroke;
		maxY += halfStroke;

		if (stats.bounds == null) {
			stats.bounds = {
				x: minX,
				y: minY,
				width: maxX - minX,
				height: maxY - minY
			};
			return;
		}

		var bounds = stats.bounds;
		var boundsMaxX = bounds.x + bounds.width;
		var boundsMaxY = bounds.y + bounds.height;
		if (minX < bounds.x) bounds.x = minX;
		if (minY < bounds.y) bounds.y = minY;
		if (maxX > boundsMaxX) boundsMaxX = maxX;
		if (maxY > boundsMaxY) boundsMaxY = maxY;
		bounds.width = boundsMaxX - bounds.x;
		bounds.height = boundsMaxY - bounds.y;
	}

	function buildRootTransform(svgElement:Xml):Matrix {
		var matrix = new Matrix();
		var viewBox = svgElement.get("viewBox");
		if (viewBox == null) {
			return matrix;
		}

		var values = parseNumberList(viewBox);
		if (values.length != 4 || values[2] == 0 || values[3] == 0) {
			return matrix;
		}

		matrix.translate(-values[0], -values[1]);
		var width = parseOptionalNumber(svgElement.get("width"));
		var height = parseOptionalNumber(svgElement.get("height"));
		if (width != null && height != null) {
			matrix.scale(width / values[2], height / values[3]);
		}
		return matrix;
	}

	function resolveStyle(node:Xml, inherited:SVGNodeStyle, stats:SVGRenderStats):SVGNodeStyle {
		var style = SVGDocument.cloneStyle(inherited);
		var styleAttributes = parseStyleAttributes(node.get("style"));

		var colorValue = getStyleValue(node, styleAttributes, "color");
		if (colorValue != null) {
			var colorResult = parsePaint(colorValue, inherited.color);
			if (colorResult.color != null) {
				style.color = colorResult.color;
			}
			if (colorResult.usedCurrentColor) {
				stats.currentColorUseCount++;
			}
		}

		var fillValue = getStyleValue(node, styleAttributes, "fill");
		if (fillValue != null) {
			var fillResult = parsePaint(fillValue, style.color);
			style.fill = fillResult.color;
			if (fillResult.usedCurrentColor) {
				stats.currentColorUseCount++;
			}
		}

		var strokeValue = getStyleValue(node, styleAttributes, "stroke");
		if (strokeValue != null) {
			var strokeResult = parsePaint(strokeValue, style.color);
			style.stroke = strokeResult.color;
			if (strokeResult.usedCurrentColor) {
				stats.currentColorUseCount++;
			}
		}

		var strokeWidth = getStyleValue(node, styleAttributes, "stroke-width");
		if (strokeWidth != null) {
			style.strokeWidth = parseNumber(strokeWidth, style.strokeWidth);
		}

		var opacity = getStyleValue(node, styleAttributes, "opacity");
		if (opacity != null) {
			style.opacity *= clamp01(parseNumber(opacity, 1));
		}

		var fillOpacity = getStyleValue(node, styleAttributes, "fill-opacity");
		if (fillOpacity != null) {
			style.fillOpacity *= clamp01(parseNumber(fillOpacity, 1));
		}

		var strokeOpacity = getStyleValue(node, styleAttributes, "stroke-opacity");
		if (strokeOpacity != null) {
			style.strokeOpacity *= clamp01(parseNumber(strokeOpacity, 1));
		}

		var fillRuleValue = getStyleValue(node, styleAttributes, "fill-rule");
		if (fillRuleValue != null) {
			var trimmed = fillRuleValue.trim().toLowerCase();
			if (trimmed == "evenodd") {
				style.fillRule = SVGFillRule.EvenOdd;
			} else if (trimmed == "nonzero") {
				style.fillRule = SVGFillRule.NonZero;
			}
		}

		var lineJoinValue = getStyleValue(node, styleAttributes, "stroke-linejoin");
		if (lineJoinValue != null) {
			var trimmed = lineJoinValue.trim().toLowerCase();
			if (trimmed == "round") {
				style.strokeLineJoin = SVGStrokeLineJoin.Round;
			} else if (trimmed == "bevel") {
				style.strokeLineJoin = SVGStrokeLineJoin.Bevel;
			} else if (trimmed == "miter") {
				style.strokeLineJoin = SVGStrokeLineJoin.Miter;
			}
		}

		var lineCapValue = getStyleValue(node, styleAttributes, "stroke-linecap");
		if (lineCapValue != null) {
			var trimmed = lineCapValue.trim().toLowerCase();
			if (trimmed == "round") {
				style.strokeLineCap = SVGStrokeLineCap.Round;
			} else if (trimmed == "square") {
				style.strokeLineCap = SVGStrokeLineCap.Square;
			} else if (trimmed == "butt") {
				style.strokeLineCap = SVGStrokeLineCap.Butt;
			}
		}

		var miterLimitValue = getStyleValue(node, styleAttributes, "stroke-miterlimit");
		if (miterLimitValue != null) {
			style.strokeMiterLimit = Math.max(1, parseNumber(miterLimitValue, style.strokeMiterLimit));
		}

		return style;
	}

	function createDefaultStyle():SVGNodeStyle {
		return {
			color: currentColor,
			fill: 0x000000,
			stroke: null,
			strokeWidth: 1,
			opacity: 1,
			fillOpacity: 1,
			strokeOpacity: 1,
			fillRule: SVGFillRule.NonZero,
			strokeLineJoin: SVGStrokeLineJoin.Miter,
			strokeLineCap: SVGStrokeLineCap.Butt,
			strokeMiterLimit: 4
		};
	}

	function getStyleValue(node:Xml, styleAttributes:Map<String, String>, name:String):Null<String> {
		if (styleAttributes.exists(name)) {
			return styleAttributes.get(name);
		}
		return node.get(name);
	}

	function parseStyleAttributes(styleValue:Null<String>):Map<String, String> {
		var values:Map<String, String> = [];
		if (styleValue == null) {
			return values;
		}

		for (entry in styleValue.split(";")) {
			var trimmed = entry.trim();
			if (trimmed == "") {
				continue;
			}
			var separator = trimmed.indexOf(":");
			if (separator < 0) {
				continue;
			}
			var key = trimmed.substring(0, separator).trim();
			var value = trimmed.substring(separator + 1).trim();
			values.set(key, value);
		}
		return values;
	}

	function parsePaint(value:Null<String>, inheritedColor:Int):SVGPaintResult {
		if (value == null) {
			return {color: null, usedCurrentColor: false};
		}

		var trimmed = value.trim();
		if (trimmed == "" || trimmed == "none" || trimmed == "transparent") {
			return {color: null, usedCurrentColor: false};
		}

		if (trimmed == "currentColor") {
			return {color: inheritedColor, usedCurrentColor: true};
		}

		return {color: parseColor(trimmed), usedCurrentColor: false};
	}

	function parseColor(value:String):Int {
		var normalized = value.trim();
		var lower = normalized.toLowerCase();
		switch (lower) {
			case "black":
				return 0x000000;
			case "white":
				return 0xFFFFFF;
			case "red":
				return 0xFF0000;
			case "green":
				return 0x008000;
			case "blue":
				return 0x0000FF;
			case "yellow":
				return 0xFFFF00;
			case "gray", "grey":
				return 0x808080;
			case "silver":
				return 0xC0C0C0;
			case "purple":
				return 0x800080;
			case "orange":
				return 0xFFA500;
			case "pink":
				return 0xFFC0CB;
			case "brown":
				return 0xA52A2A;
			case "cyan", "aqua":
				return 0x00FFFF;
			case "magenta", "fuchsia":
				return 0xFF00FF;
			case "lime":
				return 0x00FF00;
			case "navy":
				return 0x000080;
			case "teal":
				return 0x008080;
			case "maroon":
				return 0x800000;
			case "olive":
				return 0x808000;
		}

		if (normalized.startsWith("#")) {
			var hex = normalized.substring(1);
			if (hex.length == 3) {
				var r = hex.charAt(0);
				var g = hex.charAt(1);
				var b = hex.charAt(2);
				hex = r + r + g + g + b + b;
			} else if (hex.length == 4) {
				var r = hex.charAt(0);
				var g = hex.charAt(1);
				var b = hex.charAt(2);
				hex = r + r + g + g + b + b;
			} else if (hex.length == 8) {
				hex = hex.substring(0, 6);
			}
			return Std.parseInt("0x" + hex);
		}

		var lowerValue = normalized.toLowerCase();
		if (lowerValue.startsWith("rgb(") || lowerValue.startsWith("rgba(")) {
			var values = parseNumberList(normalized.substring(normalized.indexOf("(") + 1, normalized.lastIndexOf(")")));
			if (values.length >= 3) {
				var r = Std.int(hxd.Math.clamp(values[0], 0, 255));
				var g = Std.int(hxd.Math.clamp(values[1], 0, 255));
				var b = Std.int(hxd.Math.clamp(values[2], 0, 255));
				return (r << 16) | (g << 8) | b;
			}
		}

		return Std.parseInt("0x" + normalized);
	}

	function parseTransform(value:Null<String>):Matrix {
		var transform = new Matrix();
		if (value == null || value.trim() == "") {
			return transform;
		}

		var source = value.trim();
		var index = 0;
		while (index < source.length) {
			while (index < source.length && source.charCodeAt(index) <= 32) {
				index++;
			}
			if (index >= source.length) {
				break;
			}

			var nameStart = index;
			while (index < source.length && source.charAt(index) != "(") {
				index++;
			}
			if (index >= source.length) {
				break;
			}

			var name = source.substring(nameStart, index).trim();
			index++;
			var depth = 1;
			var argsStart = index;
			while (index < source.length && depth > 0) {
				var ch = source.charAt(index);
				if (ch == "(") {
					depth++;
				} else if (ch == ")") {
					depth--;
					if (depth == 0) {
						break;
					}
				}
				index++;
			}

			var args = source.substring(argsStart, index);
			index++;
			var values = parseNumberList(args);
			appendTransformCommand(transform, name, values);
		}

		return transform;
	}

	function appendTransformCommand(target:Matrix, name:String, values:Array<Float>):Void {
		var command = name.trim().toLowerCase();
		switch (command) {
			case "translate":
				var tx = values.length > 0 ? values[0] : 0;
				var ty = values.length > 1 ? values[1] : 0;
				target.translate(tx, ty);
			case "scale":
				var sx = values.length > 0 ? values[0] : 1;
				var sy = values.length > 1 ? values[1] : sx;
				target.scale(sx, sy);
			case "rotate":
				if (values.length == 1) {
					target.rotate(hxd.Math.degToRad(values[0]));
				} else if (values.length >= 3) {
					target.translate(values[1], values[2]);
					target.rotate(hxd.Math.degToRad(values[0]));
					target.translate(-values[1], -values[2]);
				}
			case "skewx":
				if (values.length > 0) {
					target.skewX(hxd.Math.degToRad(values[0]));
				}
			case "skewy":
				if (values.length > 0) {
					target.skewY(hxd.Math.degToRad(values[0]));
				}
			case "matrix":
				if (values.length >= 6) {
					var matrix = new Matrix();
					matrix.a = values[0];
					matrix.b = values[1];
					matrix.c = values[2];
					matrix.d = values[3];
					matrix.x = values[4];
					matrix.y = values[5];
					var combined = new Matrix();
					combined.multiply(target, matrix);
					target.a = combined.a;
					target.b = combined.b;
					target.c = combined.c;
					target.d = combined.d;
					target.x = combined.x;
					target.y = combined.y;
				}
			default:
		}
	}

	function appendMatrix(left:Matrix, right:Matrix):Matrix {
		var matrix = new Matrix();
		matrix.multiply(right, left);
		return matrix;
	}

	function parsePathData(data:String):Array<SVGPolyline> {
		var result:Array<SVGPolyline> = [];
		var index = 0;
		var current = point(0, 0);
		var subpathStart = point(0, 0);
		var currentPoints:Array<SVGPoint> = [];
		var currentClosed = false;
		var lastCommand = "";
		var lastCubicControl:Null<SVGPoint> = null;
		var lastQuadraticControl:Null<SVGPoint> = null;

		inline function finishSubpath() {
			if (currentPoints.length > 0) {
				result.push({
					points: currentPoints,
					closed: currentClosed
				});
			}
			currentPoints = [];
			currentClosed = false;
		}

		inline function startSubpath(pt:SVGPoint) {
			finishSubpath();
			currentPoints = [clonePoint(pt)];
			current = clonePoint(pt);
			subpathStart = clonePoint(pt);
		}

		inline function pushLine(pt:SVGPoint) {
			if (currentPoints.length == 0) {
				currentPoints.push(clonePoint(current));
			}
			currentPoints.push(clonePoint(pt));
			current = clonePoint(pt);
		}

		while (true) {
			index = skipNumberSeparators(data, index);
			if (index >= data.length) {
				break;
			}

			var ch = data.charAt(index);
			if (isPathCommand(ch)) {
				lastCommand = ch;
				index++;
			}
			if (lastCommand == "") {
				break;
			}

			var command = lastCommand.toUpperCase();
			var isRelative = lastCommand != command;

			switch (command) {
				case "M":
					if (!hasNumberAhead(data, index)) {
						continue;
					}
					var firstPoint = true;
					while (hasNumberAhead(data, index)) {
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						if (firstPoint) {
							startSubpath(destination);
							firstPoint = false;
						} else {
							pushLine(destination);
						}
					}
					lastCubicControl = null;
					lastQuadraticControl = null;
				case "L":
					while (hasNumberAhead(data, index)) {
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						pushLine(point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value));
					}
					lastCubicControl = null;
					lastQuadraticControl = null;
				case "H":
					while (hasNumberAhead(data, index)) {
						var x = readNumber(data, index);
						index = x.next;
						pushLine(point(isRelative ? current.x + x.value : x.value, current.y));
					}
					lastCubicControl = null;
					lastQuadraticControl = null;
				case "V":
					while (hasNumberAhead(data, index)) {
						var y = readNumber(data, index);
						index = y.next;
						pushLine(point(current.x, isRelative ? current.y + y.value : y.value));
					}
					lastCubicControl = null;
					lastQuadraticControl = null;
				case "C":
					while (hasNumberAhead(data, index)) {
						var x1 = readNumber(data, index);
						index = x1.next;
						var y1 = readNumber(data, index);
						index = y1.next;
						var x2 = readNumber(data, index);
						index = x2.next;
						var y2 = readNumber(data, index);
						index = y2.next;
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var c1 = point(isRelative ? current.x + x1.value : x1.value, isRelative ? current.y + y1.value : y1.value);
						var c2 = point(isRelative ? current.x + x2.value : x2.value, isRelative ? current.y + y2.value : y2.value);
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						appendCubicPoints(currentPoints, current, c1, c2, destination);
						current = clonePoint(destination);
						lastCubicControl = clonePoint(c2);
						lastQuadraticControl = null;
					}
				case "S":
					while (hasNumberAhead(data, index)) {
						var x2 = readNumber(data, index);
						index = x2.next;
						var y2 = readNumber(data, index);
						index = y2.next;
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var c1 = lastCubicControl == null ? clonePoint(current) : reflectPoint(lastCubicControl, current);
						var c2 = point(isRelative ? current.x + x2.value : x2.value, isRelative ? current.y + y2.value : y2.value);
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						appendCubicPoints(currentPoints, current, c1, c2, destination);
						current = clonePoint(destination);
						lastCubicControl = clonePoint(c2);
						lastQuadraticControl = null;
					}
				case "Q":
					while (hasNumberAhead(data, index)) {
						var x1 = readNumber(data, index);
						index = x1.next;
						var y1 = readNumber(data, index);
						index = y1.next;
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var control = point(isRelative ? current.x + x1.value : x1.value, isRelative ? current.y + y1.value : y1.value);
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						appendQuadraticPoints(currentPoints, current, control, destination);
						current = clonePoint(destination);
						lastQuadraticControl = clonePoint(control);
						lastCubicControl = null;
					}
				case "T":
					while (hasNumberAhead(data, index)) {
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var control = lastQuadraticControl == null ? clonePoint(current) : reflectPoint(lastQuadraticControl, current);
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						appendQuadraticPoints(currentPoints, current, control, destination);
						current = clonePoint(destination);
						lastQuadraticControl = clonePoint(control);
						lastCubicControl = null;
					}
				case "A":
					while (hasNumberAhead(data, index)) {
						var rx = readNumber(data, index);
						index = rx.next;
						var ry = readNumber(data, index);
						index = ry.next;
						var rotation = readNumber(data, index);
						index = rotation.next;
						var largeArc = readNumber(data, index);
						index = largeArc.next;
						var sweep = readNumber(data, index);
						index = sweep.next;
						var x = readNumber(data, index);
						index = x.next;
						var y = readNumber(data, index);
						index = y.next;
						var destination = point(isRelative ? current.x + x.value : x.value, isRelative ? current.y + y.value : y.value);
						appendArcPoints(currentPoints, current, rx.value, ry.value, rotation.value, largeArc.value != 0, sweep.value != 0, destination);
						current = clonePoint(destination);
						lastCubicControl = null;
						lastQuadraticControl = null;
					}
				case "Z":
					currentClosed = true;
					if (currentPoints.length > 0 && !samePoint(currentPoints[currentPoints.length - 1], subpathStart)) {
						currentPoints.push(clonePoint(subpathStart));
					}
					current = clonePoint(subpathStart);
					finishSubpath();
					lastCubicControl = null;
					lastQuadraticControl = null;
				default:
			}
		}

		finishSubpath();
		return result;
	}

	function appendQuadraticPoints(points:Array<SVGPoint>, start:SVGPoint, control:SVGPoint, destination:SVGPoint):Void {
		if (points.length == 0) {
			points.push(clonePoint(start));
		}
		var segments = curveSegmentCount([start, control, destination]);
		for (i in 1...segments + 1) {
			var t = i / segments;
			var mt = 1 - t;
			points.push(point(
				mt * mt * start.x + 2 * mt * t * control.x + t * t * destination.x,
				mt * mt * start.y + 2 * mt * t * control.y + t * t * destination.y
			));
		}
	}

	function appendCubicPoints(points:Array<SVGPoint>, start:SVGPoint, controlA:SVGPoint, controlB:SVGPoint, destination:SVGPoint):Void {
		if (points.length == 0) {
			points.push(clonePoint(start));
		}
		var segments = curveSegmentCount([start, controlA, controlB, destination]);
		for (i in 1...segments + 1) {
			var t = i / segments;
			var mt = 1 - t;
			points.push(point(
				mt * mt * mt * start.x + 3 * mt * mt * t * controlA.x + 3 * mt * t * t * controlB.x + t * t * t * destination.x,
				mt * mt * mt * start.y + 3 * mt * mt * t * controlA.y + 3 * mt * t * t * controlB.y + t * t * t * destination.y
			));
		}
	}

	static function appendArcPoints(
		points:Array<SVGPoint>,
		start:SVGPoint,
		rxValue:Float,
		ryValue:Float,
		rotationDegrees:Float,
		largeArc:Bool,
		sweep:Bool,
		destination:SVGPoint
	):Void {
		if (points.length == 0) {
			points.push(clonePoint(start));
		}

		var rx = Math.abs(rxValue);
		var ry = Math.abs(ryValue);
		if ((rx == 0 && ry == 0) || samePoint(start, destination)) {
			points.push(clonePoint(destination));
			return;
		}

		var phi = hxd.Math.degToRad(rotationDegrees);
		var cosPhi = Math.cos(phi);
		var sinPhi = Math.sin(phi);
		var dx2 = (start.x - destination.x) * 0.5;
		var dy2 = (start.y - destination.y) * 0.5;
		var x1p = cosPhi * dx2 + sinPhi * dy2;
		var y1p = -sinPhi * dx2 + cosPhi * dy2;

		var rxSq = rx * rx;
		var rySq = ry * ry;
		var x1pSq = x1p * x1p;
		var y1pSq = y1p * y1p;
		var lambda = x1pSq / rxSq + y1pSq / rySq;
		if (lambda > 1) {
			var scale = Math.sqrt(lambda);
			rx *= scale;
			ry *= scale;
			rxSq = rx * rx;
			rySq = ry * ry;
		}

		var numerator = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq;
		var denominator = rxSq * y1pSq + rySq * x1pSq;
		var factor = denominator == 0 ? 0 : Math.sqrt(Math.max(0, numerator / denominator));
		if (largeArc == sweep) {
			factor = -factor;
		}

		var cxp = factor * ((rx * y1p) / ry);
		var cyp = factor * (-(ry * x1p) / rx);
		var cx = cosPhi * cxp - sinPhi * cyp + (start.x + destination.x) * 0.5;
		var cy = sinPhi * cxp + cosPhi * cyp + (start.y + destination.y) * 0.5;

		var startVector = point((x1p - cxp) / rx, (y1p - cyp) / ry);
		var endVector = point((-x1p - cxp) / rx, (-y1p - cyp) / ry);
		var startAngle = vectorAngle(point(1, 0), startVector);
		var deltaAngle = vectorAngle(startVector, endVector);

		if (!sweep && deltaAngle > 0) {
			deltaAngle -= Math.PI * 2;
		} else if (sweep && deltaAngle < 0) {
			deltaAngle += Math.PI * 2;
		}

		var segments = Std.int(Math.ceil(Math.abs(deltaAngle) / (Math.PI / 8)));
		if (segments < 4) {
			segments = 4;
		}

		for (i in 1...segments + 1) {
			var angle = startAngle + (deltaAngle * i / segments);
			var cosAngle = Math.cos(angle);
			var sinAngle = Math.sin(angle);
			points.push(point(
				cx + cosPhi * rx * cosAngle - sinPhi * ry * sinAngle,
				cy + sinPhi * rx * cosAngle + cosPhi * ry * sinAngle
			));
		}
	}

	static function vectorAngle(from:SVGPoint, to:SVGPoint):Float {
		var dot = from.x * to.x + from.y * to.y;
		var length = Math.sqrt((from.x * from.x + from.y * from.y) * (to.x * to.x + to.y * to.y));
		var angle = Math.acos(hxd.Math.clamp(dot / length, -1, 1));
		var cross = from.x * to.y - from.y * to.x;
		return cross < 0 ? -angle : angle;
	}

	function curveSegmentCount(points:Array<SVGPoint>):Int {
		var total = 0.0;
		for (i in 1...points.length) {
			total += distance(points[i - 1], points[i]);
		}
		var segments = Std.int(Math.ceil(total / 6));
		if (segments < 6) {
			segments = 6;
		} else if (segments > 32) {
			segments = 32;
		}
		return segments;
	}

	function createEllipsePolyline(cx:Float, cy:Float, rx:Float, ry:Float, ?segments:Int):SVGPolyline {
		var count = segments == null ? Std.int(Math.ceil(Math.PI * Math.max(rx, ry) / 2)) : segments;
		if (count < 16) {
			count = 16;
		}
		var points:Array<SVGPoint> = [];
		for (i in 0...count) {
			var angle = (Math.PI * 2 * i) / count;
			points.push(point(cx + Math.cos(angle) * rx, cy + Math.sin(angle) * ry));
		}
		return {
			points: points,
			closed: true
		};
	}

	static function appendEllipseArc(
		points:Array<SVGPoint>,
		cx:Float,
		cy:Float,
		rx:Float,
		ry:Float,
		startAngle:Float,
		endAngle:Float,
		segments:Int,
		includeStart:Bool
	):Void {
		for (i in 0...segments + 1) {
			if (i == 0 && !includeStart) {
				continue;
			}
			var ratio = i / segments;
			var angle = startAngle + (endAngle - startAngle) * ratio;
			points.push(point(cx + Math.cos(angle) * rx, cy + Math.sin(angle) * ry));
		}
	}

	function transformPolyline(polyline:SVGPolyline, matrix:Matrix):SVGPolyline {
		var points:Array<SVGPoint> = [];
		for (pt in polyline.points) {
			points.push(transformPoint(pt, matrix));
		}
		return {
			points: points,
			closed: polyline.closed
		};
	}

	function transformPoint(pt:SVGPoint, matrix:Matrix):SVGPoint {
		return point(pt.x * matrix.a + pt.y * matrix.c + matrix.x, pt.x * matrix.b + pt.y * matrix.d + matrix.y);
	}

	function parsePoints(pointsString:Null<String>):Array<SVGPoint> {
		var points:Array<SVGPoint> = [];
		if (pointsString == null) {
			return points;
		}

		var values = parseNumberList(pointsString);
		var index = 0;
		while (index + 1 < values.length) {
			points.push(point(values[index], values[index + 1]));
			index += 2;
		}
		return points;
	}

	function parseNumberList(input:String):Array<Float> {
		var values:Array<Float> = [];
		var index = 0;
		while (hasNumberAhead(input, index)) {
			var result = readNumber(input, index);
			values.push(result.value);
			index = result.next;
		}
		return values;
	}

	function parseOptionalNumber(value:Null<String>):Null<Float> {
		if (value == null) {
			return null;
		}
		return parseNumber(value, 0);
	}

	function parseNumber(value:Null<String>, defaultValue:Float):Float {
		if (value == null) {
			return defaultValue;
		}

		var index = skipNumberSeparators(value, 0);
		if (index >= value.length) {
			return defaultValue;
		}

		var result = readNumber(value, index);
		return Math.isNaN(result.value) ? defaultValue : result.value;
	}

	function hasNumberAhead(input:String, index:Int):Bool {
		var next = skipNumberSeparators(input, index);
		if (next >= input.length) {
			return false;
		}
		var code = input.charCodeAt(next);
		return (code >= "0".code && code <= "9".code) || code == "-".code || code == "+".code || code == ".".code;
	}

	function skipNumberSeparators(input:String, index:Int):Int {
		var next = index;
		while (next < input.length) {
			var code = input.charCodeAt(next);
			if (code <= 32 || code == ",".code) {
				next++;
				continue;
			}
			break;
		}
		return next;
	}

	function readNumber(input:String, index:Int):{value:Float, next:Int} {
		var start = skipNumberSeparators(input, index);
		var next = start;

		if (next < input.length) {
			var sign = input.charAt(next);
			if (sign == "+" || sign == "-") {
				next++;
			}
		}

		var seenDot = false;
		var seenExponent = false;
		while (next < input.length) {
			var ch = input.charAt(next);
			var code = input.charCodeAt(next);
			if (code >= "0".code && code <= "9".code) {
				next++;
				continue;
			}
			if (ch == "." && !seenDot && !seenExponent) {
				seenDot = true;
				next++;
				continue;
			}
			if ((ch == "e" || ch == "E") && !seenExponent) {
				seenExponent = true;
				next++;
				if (next < input.length) {
					var exponentSign = input.charAt(next);
					if (exponentSign == "+" || exponentSign == "-") {
						next++;
					}
				}
				continue;
			}
			break;
		}

		var token = input.substring(start, next);
		return {
			value: Std.parseFloat(token),
			next: next
		};
	}

	function isPathCommand(char:String):Bool {
		return char >= "A" && char <= "Z" || char >= "a" && char <= "z";
	}

	function reflectPoint(control:SVGPoint, around:SVGPoint):SVGPoint {
		return point(around.x * 2 - control.x, around.y * 2 - control.y);
	}

	function distance(a:SVGPoint, b:SVGPoint):Float {
		return Math.sqrt(distanceSquared(a, b));
	}

	static function distanceSquared(a:SVGPoint, b:SVGPoint):Float {
		var dx = b.x - a.x;
		var dy = b.y - a.y;
		return dx * dx + dy * dy;
	}

	static function samePoint(a:SVGPoint, b:SVGPoint):Bool {
		return distanceSquared(a, b) <= 1e-9;
	}

	function clamp01(value:Float):Float {
		return hxd.Math.clamp(value, 0, 1);
	}

	static function point(x:Float, y:Float):SVGPoint {
		return {x: x, y: y};
	}

	static function clonePoint(pt:SVGPoint):SVGPoint {
		return point(pt.x, pt.y);
	}
}
