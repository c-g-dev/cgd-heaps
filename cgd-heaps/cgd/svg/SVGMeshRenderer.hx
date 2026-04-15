package cgd.svg;

import cgd.svg.SVGDocument.SVGFillRule;
import cgd.svg.SVGDocument.SVGPoint;
import cgd.svg.SVGDocument.SVGPolyline;
import cgd.svg.SVGDocument.SVGRenderStats;
import cgd.svg.SVGDocument.SVGShape;
import cgd.svg.SVGDocument.SVGStrokeLineCap;
import cgd.svg.SVGDocument.SVGStrokeLineJoin;

private typedef NestingNode = {
	var index:Int;
	var children:Array<NestingNode>;
}

private typedef FillGroup = {
	var outerIndex:Int;
	var holeIndices:Array<Int>;
}

class SVGMeshDrawable extends h2d.Drawable {
	public var vertexCount(default, null):Int = 0;

	var vertices:hxd.FloatBuffer;
	var indices:hxd.IndexBuffer;
	var indexCount:Int = 0;
	var gpuBuffer:h3d.Buffer;
	var gpuIndices:h3d.Indexes;
	var drawState:h2d.impl.BatchDrawState;
	var tile:h2d.Tile;
	var dirty:Bool = false;
	var xMin:Float = 1e20;
	var yMin:Float = 1e20;
	var xMax:Float = -1e20;
	var yMax:Float = -1e20;

	public function new(?parent:h2d.Object) {
		super(parent);
		vertices = new hxd.FloatBuffer();
		indices = new hxd.IndexBuffer();
		drawState = new h2d.impl.BatchDrawState();
		tile = h2d.Tile.fromColor(0xFFFFFF);
		drawState.setTile(tile);
	}

	public function clear() {
		disposeGpu();
		vertices = new hxd.FloatBuffer();
		indices = new hxd.IndexBuffer();
		vertexCount = 0;
		indexCount = 0;
		drawState.clear();
		drawState.setTile(tile);
		dirty = false;
		xMin = 1e20;
		yMin = 1e20;
		xMax = -1e20;
		yMax = -1e20;
	}

	public function addVertex(x:Float, y:Float, r:Float, g:Float, b:Float, a:Float):Int {
		vertices.push(x);
		vertices.push(y);
		vertices.push(0);
		vertices.push(0);
		vertices.push(r);
		vertices.push(g);
		vertices.push(b);
		vertices.push(a);
		if (x < xMin)
			xMin = x;
		if (y < yMin)
			yMin = y;
		if (x > xMax)
			xMax = x;
		if (y > yMax)
			yMax = y;
		var idx = vertexCount;
		vertexCount++;
		dirty = true;
		return idx;
	}

	public function addTriangle(i0:Int, i1:Int, i2:Int) {
		indices.push(i0);
		indices.push(i1);
		indices.push(i2);
		drawState.add(3);
		indexCount += 3;
		dirty = true;
	}

	function ensureUploaded() {
		var needsUpload = dirty;
		if (!needsUpload && gpuBuffer != null && gpuBuffer.isDisposed())
			needsUpload = true;
		if (!needsUpload)
			return;
		disposeGpu();
		if (vertexCount > 0 && indexCount > 0) {
			var alloc = hxd.impl.Allocator.get();
			gpuBuffer = alloc.ofFloats(vertices, hxd.BufferFormat.H2D);
			gpuIndices = alloc.ofIndexes(indices);
		}
		dirty = false;
	}

	function disposeGpu() {
		var alloc = hxd.impl.Allocator.get();
		if (gpuBuffer != null) {
			alloc.disposeBuffer(gpuBuffer);
			gpuBuffer = null;
		}
		if (gpuIndices != null) {
			alloc.disposeIndexBuffer(gpuIndices);
			gpuIndices = null;
		}
	}

	override function draw(ctx:h2d.RenderContext) {
		if (vertexCount == 0 || indexCount == 0)
			return;
		ensureUploaded();
		if (gpuBuffer == null || gpuIndices == null)
			return;
		if (!ctx.beginDrawBatchState(this))
			return;
		drawState.drawIndexed(ctx, gpuBuffer, gpuIndices);
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);
		ensureUploaded();
	}

	override function getBoundsRec(relativeTo, out, forSize) {
		super.getBoundsRec(relativeTo, out, forSize);
		if (xMax > xMin && yMax > yMin) {
			addBounds(relativeTo, out, xMin, yMin, xMax - xMin, yMax - yMin);
		}
	}

	override function onRemove() {
		super.onRemove();
		disposeGpu();
	}
}

class SVGMeshRenderer {
	public var lastStats(default, null):Null<SVGRenderStats>;

	var unitSize:Int = 1;

	public function new() {}

	public function setUnitSize(unitSize:Int) {
		this.unitSize = unitSize;
	}

	public function inspect(document:SVGDocument):SVGRenderStats {
		return SVGDocument.scaleStats(document.stats, unitSize);
	}

	public function render(document:SVGDocument, target:SVGMeshDrawable):SVGRenderStats {
		var stats = inspect(document);
		lastStats = stats;
		target.clear();
		for (shape in document.shapes) {
			drawShape(target, shape);
		}
		return stats;
	}

	function drawShape(target:SVGMeshDrawable, shape:SVGShape):Void {
		if (shape.style.fill != null) {
			drawFill(target, shape);
		}
		if (shape.style.stroke != null && shape.style.strokeWidth > 0) {
			drawStroke(target, shape);
		}
	}

	function drawFill(target:SVGMeshDrawable, shape:SVGShape):Void {
		var closedPaths = new Array<SVGPolyline>();
		for (p in shape.polylines) {
			if (p.closed)
				closedPaths.push(p);
		}
		if (closedPaths.length == 0)
			return;

		var color = shape.style.fill;
		var alpha = shape.style.opacity * shape.style.fillOpacity;
		var r = ((color >> 16) & 0xFF) / 255.0;
		var g = ((color >> 8) & 0xFF) / 255.0;
		var b = (color & 0xFF) / 255.0;

		var stripped = new Array<Array<SVGPoint>>();
		for (p in closedPaths) {
			stripped.push(stripClosingPoint(p.points));
		}

		if (stripped.length == 1) {
			triangulateGroup(target, stripped[0], null, r, g, b, alpha);
			return;
		}

		var groups = classifyPaths(stripped, shape.style.fillRule);
		for (group in groups) {
			var outerPts = stripped[group.outerIndex];
			if (group.holeIndices.length == 0) {
				triangulateGroup(target, outerPts, null, r, g, b, alpha);
			} else {
				var allPts = outerPts.copy();
				var holeStarts = new Array<Int>();
				for (hi in group.holeIndices) {
					holeStarts.push(allPts.length);
					for (pt in stripped[hi]) {
						allPts.push(pt);
					}
				}
				triangulateGroup(target, allPts, holeStarts, r, g, b, alpha);
			}
		}
	}

	function drawStroke(target:SVGMeshDrawable, shape:SVGShape):Void {
		var color = shape.style.stroke;
		var alpha = shape.style.opacity * shape.style.strokeOpacity;
		var r = ((color >> 16) & 0xFF) / 255.0;
		var g = ((color >> 8) & 0xFF) / 255.0;
		var b = (color & 0xFF) / 255.0;
		var halfWidth = shape.style.strokeWidth * 0.5;

		for (polyline in shape.polylines) {
			tessellateStroke(
				target,
				polyline,
				halfWidth,
				r,
				g,
				b,
				alpha,
				shape.style.strokeLineJoin,
				shape.style.strokeLineCap,
				shape.style.strokeMiterLimit
			);
		}
	}

	function tessellateStroke(
		target:SVGMeshDrawable,
		polyline:SVGPolyline,
		halfWidth:Float,
		r:Float,
		g:Float,
		b:Float,
		a:Float,
		lineJoin:SVGStrokeLineJoin,
		lineCap:SVGStrokeLineCap,
		miterLimit:Float
	):Void {
		var pts = sanitizeStrokePoints(polyline);
		var n = pts.length;
		var closed = polyline.closed;
		if (n < 2 || halfWidth <= 0)
			return;
		if (closed && n < 3)
			return;

		if (closed) {
			for (i in 0...n) {
				drawStrokeSegment(target, pts[i], pts[(i + 1) % n], halfWidth, false, false, r, g, b, a);
			}
			for (i in 0...n) {
				addStrokeJoin(target, pts[(i + n - 1) % n], pts[i], pts[(i + 1) % n], halfWidth, r, g, b, a, lineJoin, miterLimit);
			}
			return;
		}

		for (i in 0...n - 1) {
			drawStrokeSegment(target, pts[i], pts[i + 1], halfWidth, i == 0 && lineCap == SVGStrokeLineCap.Square, i == n - 2 && lineCap == SVGStrokeLineCap.Square, r, g, b, a);
		}
		for (i in 1...n - 1) {
			addStrokeJoin(target, pts[i - 1], pts[i], pts[i + 1], halfWidth, r, g, b, a, lineJoin, miterLimit);
		}
		switch (lineCap) {
			case Round:
				addRoundCap(target, pts[0], pts[1], halfWidth, true, r, g, b, a);
				addRoundCap(target, pts[n - 1], pts[n - 2], halfWidth, false, r, g, b, a);
			case Butt, Square:
		}
	}

	function sanitizeStrokePoints(polyline:SVGPolyline):Array<SVGPoint> {
		var result = new Array<SVGPoint>();
		for (pt in polyline.points) {
			if (result.length == 0 || !samePoint(result[result.length - 1], pt)) {
				result.push(pt);
			}
		}
		if (polyline.closed && result.length > 1 && samePoint(result[0], result[result.length - 1])) {
			result.pop();
		}
		return result;
	}

	function drawStrokeSegment(
		target:SVGMeshDrawable,
		start:SVGPoint,
		finish:SVGPoint,
		halfWidth:Float,
		extendStart:Bool,
		extendEnd:Bool,
		r:Float,
		g:Float,
		b:Float,
		a:Float
	):Void {
		var dx = finish.x - start.x;
		var dy = finish.y - start.y;
		var length = Math.sqrt(dx * dx + dy * dy);
		if (length <= 1e-10) {
			return;
		}
		dx /= length;
		dy /= length;
		var nx = -dy;
		var ny = dx;
		var startShift = extendStart ? halfWidth : 0.0;
		var endShift = extendEnd ? halfWidth : 0.0;
		var x0 = start.x - dx * startShift;
		var y0 = start.y - dy * startShift;
		var x1 = finish.x + dx * endShift;
		var y1 = finish.y + dy * endShift;
		addQuad(
			target,
			x0 + nx * halfWidth,
			y0 + ny * halfWidth,
			x0 - nx * halfWidth,
			y0 - ny * halfWidth,
			x1 + nx * halfWidth,
			y1 + ny * halfWidth,
			x1 - nx * halfWidth,
			y1 - ny * halfWidth,
			r,
			g,
			b,
			a
		);
	}

	function addStrokeJoin(
		target:SVGMeshDrawable,
		prev:SVGPoint,
		curr:SVGPoint,
		next:SVGPoint,
		halfWidth:Float,
		r:Float,
		g:Float,
		b:Float,
		a:Float,
		lineJoin:SVGStrokeLineJoin,
		miterLimit:Float
	):Void {
		var prevDir = normalize(curr.x - prev.x, curr.y - prev.y);
		var nextDir = normalize(next.x - curr.x, next.y - curr.y);
		if (prevDir == null || nextDir == null) {
			return;
		}
		var turn = cross(prevDir.x, prevDir.y, nextDir.x, nextDir.y);
		if (Math.abs(turn) <= 1e-6) {
			return;
		}

		var side = turn > 0 ? 1.0 : -1.0;
		var prevNormal = point(-prevDir.y * side, prevDir.x * side);
		var nextNormal = point(-nextDir.y * side, nextDir.x * side);
		var startOuter = point(curr.x + prevNormal.x * halfWidth, curr.y + prevNormal.y * halfWidth);
		var endOuter = point(curr.x + nextNormal.x * halfWidth, curr.y + nextNormal.y * halfWidth);

		switch (lineJoin) {
			case Round:
				addRoundJoin(target, curr, startOuter, endOuter, turn < 0, halfWidth, r, g, b, a);
			case Bevel:
				addTrianglePoints(target, curr, startOuter, endOuter, r, g, b, a);
			case Miter:
				var miter = lineIntersection(startOuter, prevDir, endOuter, nextDir);
				if (miter != null && distance(curr, miter) <= Math.max(1, miterLimit) * halfWidth) {
					addTrianglePoints(target, startOuter, miter, endOuter, r, g, b, a);
				} else {
					addTrianglePoints(target, curr, startOuter, endOuter, r, g, b, a);
				}
		}
	}

	function addRoundJoin(
		target:SVGMeshDrawable,
		center:SVGPoint,
		startOuter:SVGPoint,
		endOuter:SVGPoint,
		clockwise:Bool,
		radius:Float,
		r:Float,
		g:Float,
		b:Float,
		a:Float
	):Void {
		var startAngle = Math.atan2(startOuter.y - center.y, startOuter.x - center.x);
		var endAngle = Math.atan2(endOuter.y - center.y, endOuter.x - center.x);
		addArcFan(target, center, radius, startAngle, endAngle, clockwise, r, g, b, a, startOuter, endOuter);
	}

	function addRoundCap(
		target:SVGMeshDrawable,
		center:SVGPoint,
		neighbor:SVGPoint,
		halfWidth:Float,
		atStart:Bool,
		r:Float,
		g:Float,
		b:Float,
		a:Float
	):Void {
		var dir = normalize(neighbor.x - center.x, neighbor.y - center.y);
		if (dir == null) {
			return;
		}
		if (!atStart) {
			dir = point(-dir.x, -dir.y);
		}
		var nx = -dir.y;
		var ny = dir.x;
		var left = point(center.x + nx * halfWidth, center.y + ny * halfWidth);
		var right = point(center.x - nx * halfWidth, center.y - ny * halfWidth);
		if (atStart) {
			addArcFan(target, center, halfWidth, Math.atan2(right.y - center.y, right.x - center.x), Math.atan2(left.y - center.y, left.x - center.x), true, r, g, b, a, right, left);
		} else {
			addArcFan(target, center, halfWidth, Math.atan2(left.y - center.y, left.x - center.x), Math.atan2(right.y - center.y, right.x - center.x), true, r, g, b, a, left, right);
		}
	}

	function addArcFan(
		target:SVGMeshDrawable,
		center:SVGPoint,
		radius:Float,
		startAngle:Float,
		endAngle:Float,
		clockwise:Bool,
		r:Float,
		g:Float,
		b:Float,
		a:Float,
		?startPoint:SVGPoint,
		?endPoint:SVGPoint
	):Void {
		var delta = angleDelta(startAngle, endAngle, clockwise);
		if (delta <= 1e-6) {
			return;
		}
		var segmentCount = Std.int(Math.ceil(delta / (Math.PI / 10)));
		if (segmentCount < 2) {
			segmentCount = 2;
		}
		var centerIndex = addMeshVertex(target, center.x, center.y, r, g, b, a);
		var first = startPoint == null ? point(center.x + Math.cos(startAngle) * radius, center.y + Math.sin(startAngle) * radius) : startPoint;
		var prevIndex = addMeshVertex(target, first.x, first.y, r, g, b, a);
		for (step in 1...segmentCount + 1) {
			var nextPoint:SVGPoint;
			if (step == segmentCount && endPoint != null) {
				nextPoint = endPoint;
			} else {
				var t = step / segmentCount;
				var angle = clockwise ? startAngle - delta * t : startAngle + delta * t;
				nextPoint = point(center.x + Math.cos(angle) * radius, center.y + Math.sin(angle) * radius);
			}
			var nextIndex = addMeshVertex(target, nextPoint.x, nextPoint.y, r, g, b, a);
			if (clockwise) {
				target.addTriangle(centerIndex, nextIndex, prevIndex);
			} else {
				target.addTriangle(centerIndex, prevIndex, nextIndex);
			}
			prevIndex = nextIndex;
		}
	}

	function addQuad(
		target:SVGMeshDrawable,
		left0x:Float,
		left0y:Float,
		right0x:Float,
		right0y:Float,
		left1x:Float,
		left1y:Float,
		right1x:Float,
		right1y:Float,
		r:Float,
		g:Float,
		b:Float,
		a:Float
	):Void {
		var i0 = addMeshVertex(target, left0x, left0y, r, g, b, a);
		var i1 = addMeshVertex(target, right0x, right0y, r, g, b, a);
		var i2 = addMeshVertex(target, left1x, left1y, r, g, b, a);
		var i3 = addMeshVertex(target, right1x, right1y, r, g, b, a);
		target.addTriangle(i0, i1, i2);
		target.addTriangle(i1, i3, i2);
	}

	function addTrianglePoints(target:SVGMeshDrawable, p0:SVGPoint, p1:SVGPoint, p2:SVGPoint, r:Float, g:Float, b:Float, a:Float):Void {
		var i0 = addMeshVertex(target, p0.x, p0.y, r, g, b, a);
		var i1 = addMeshVertex(target, p1.x, p1.y, r, g, b, a);
		var i2 = addMeshVertex(target, p2.x, p2.y, r, g, b, a);
		target.addTriangle(i0, i1, i2);
	}

	function addMeshVertex(target:SVGMeshDrawable, x:Float, y:Float, r:Float, g:Float, b:Float, a:Float):Int {
		return target.addVertex(x * unitSize, y * unitSize, r, g, b, a);
	}

	function point(x:Float, y:Float):SVGPoint {
		return {x: x, y: y};
	}

	function cross(ax:Float, ay:Float, bx:Float, by:Float):Float {
		return ax * by - ay * bx;
	}

	function normalize(dx:Float, dy:Float):Null<SVGPoint> {
		var length = Math.sqrt(dx * dx + dy * dy);
		if (length <= 1e-10) {
			return null;
		}
		return point(dx / length, dy / length);
	}

	function lineIntersection(originA:SVGPoint, dirA:SVGPoint, originB:SVGPoint, dirB:SVGPoint):Null<SVGPoint> {
		var denom = cross(dirA.x, dirA.y, dirB.x, dirB.y);
		if (Math.abs(denom) <= 1e-10) {
			return null;
		}
		var offset = point(originB.x - originA.x, originB.y - originA.y);
		var t = cross(offset.x, offset.y, dirB.x, dirB.y) / denom;
		return point(originA.x + dirA.x * t, originA.y + dirA.y * t);
	}

	function distance(a:SVGPoint, b:SVGPoint):Float {
		var dx = b.x - a.x;
		var dy = b.y - a.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	function angleDelta(startAngle:Float, endAngle:Float, clockwise:Bool):Float {
		if (clockwise) {
			var start = startAngle;
			while (start < endAngle) {
				start += Math.PI * 2;
			}
			return start - endAngle;
		}
		var end = endAngle;
		while (end < startAngle) {
			end += Math.PI * 2;
		}
		return end - startAngle;
	}

	// -- Fill-rule classification --

	function classifyPaths(paths:Array<Array<SVGPoint>>, fillRule:SVGFillRule):Array<FillGroup> {
		var areas = new Array<Float>();
		for (p in paths)
			areas.push(signedArea(p));
		var roots = buildNestingTree(paths, areas);
		switch (fillRule) {
			case EvenOdd:
				return collectEvenOddGroups(roots);
			case NonZero:
				return collectNonZeroGroups(roots, areas);
		}
		return [];
	}

	function buildNestingTree(paths:Array<Array<SVGPoint>>, areas:Array<Float>):Array<NestingNode> {
		var sorted = new Array<Int>();
		for (i in 0...paths.length)
			sorted.push(i);
		sorted.sort(function(a, b) {
			var aa = Math.abs(areas[a]);
			var ab = Math.abs(areas[b]);
			return aa > ab ? -1 : (aa < ab ? 1 : 0);
		});

		var nodes = new Array<NestingNode>();
		for (i in 0...paths.length) {
			nodes.push({index: i, children: new Array<NestingNode>()});
		}

		var roots = new Array<NestingNode>();
		for (idx in sorted) {
			var placed = false;
			for (root in roots) {
				if (placeInTree(nodes[idx], root, paths)) {
					placed = true;
					break;
				}
			}
			if (!placed) {
				roots.push(nodes[idx]);
			}
		}
		return roots;
	}

	function placeInTree(node:NestingNode, parent:NestingNode, paths:Array<Array<SVGPoint>>):Bool {
		if (!isContainedIn(paths[node.index], paths[parent.index]))
			return false;
		for (child in parent.children) {
			if (placeInTree(node, child, paths))
				return true;
		}
		parent.children.push(node);
		return true;
	}

	// Even-odd: depth 0 = fill, depth 1 = hole, depth 2 = fill, ...
	function collectEvenOddGroups(roots:Array<NestingNode>):Array<FillGroup> {
		var groups = new Array<FillGroup>();
		for (root in roots) {
			collectEvenOddNode(root, 0, groups);
		}
		return groups;
	}

	function collectEvenOddNode(node:NestingNode, depth:Int, groups:Array<FillGroup>):Void {
		if (depth % 2 != 0)
			return;
		var holes = new Array<Int>();
		for (child in node.children) {
			holes.push(child.index);
		}
		groups.push({outerIndex: node.index, holeIndices: holes});
		for (child in node.children) {
			for (grandchild in child.children) {
				collectEvenOddNode(grandchild, depth + 2, groups);
			}
		}
	}

	// Nonzero: accumulate winding direction along the nesting tree.
	// Fill transitions (0 → nonzero) are outers; unfill transitions (nonzero → 0) are holes.
	function collectNonZeroGroups(roots:Array<NestingNode>, areas:Array<Float>):Array<FillGroup> {
		var groups = new Array<FillGroup>();
		for (root in roots) {
			collectNonZeroNode(root, 0, areas, groups);
		}
		return groups;
	}

	function collectNonZeroNode(node:NestingNode, parentWinding:Int, areas:Array<Float>, groups:Array<FillGroup>):Void {
		var dir = areas[node.index] >= 0 ? 1 : -1;
		var cumulative = parentWinding + dir;

		if (parentWinding == 0 && cumulative != 0) {
			var holes = new Array<Int>();
			for (child in node.children) {
				var childDir = areas[child.index] >= 0 ? 1 : -1;
				if (cumulative + childDir == 0) {
					holes.push(child.index);
				}
			}
			groups.push({outerIndex: node.index, holeIndices: holes});
		}

		for (child in node.children) {
			collectNonZeroNode(child, cumulative, areas, groups);
		}
	}

	// -- Triangulation --

	function triangulateGroup(target:SVGMeshDrawable, points:Array<SVGPoint>, holes:Null<Array<Int>>, r:Float, g:Float, b:Float, a:Float):Void {
		if (points.length < 3)
			return;

		var ear = getEarcut();
		var triIndices = ear.triangulate(cast points, holes);
		if (triIndices.length < 3)
			return;

		var baseVertex = target.vertexCount;
		for (pt in points) {
			target.addVertex(pt.x * unitSize, pt.y * unitSize, r, g, b, a);
		}

		var i = 0;
		while (i + 2 < triIndices.length) {
			target.addTriangle(baseVertex + triIndices[i], baseVertex + triIndices[i + 1], baseVertex + triIndices[i + 2]);
			i += 3;
		}
	}

	// -- Geometry helpers --

	function stripClosingPoint(points:Array<SVGPoint>):Array<SVGPoint> {
		if (points.length < 2)
			return points;
		if (samePoint(points[0], points[points.length - 1]))
			return points.slice(0, points.length - 1);
		return points;
	}

	function signedArea(points:Array<SVGPoint>):Float {
		var n = points.length;
		if (n < 3)
			return 0;
		var sum = 0.0;
		var j = n - 1;
		for (i in 0...n) {
			sum += (points[j].x - points[i].x) * (points[j].y + points[i].y);
			j = i;
		}
		return sum * 0.5;
	}

	function isContainedIn(inner:Array<SVGPoint>, outer:Array<SVGPoint>):Bool {
		if (inner.length == 0)
			return false;
		return pointInPolygon(inner[0], outer);
	}

	function pointInPolygon(pt:SVGPoint, polygon:Array<SVGPoint>):Bool {
		var n = polygon.length;
		if (n < 3)
			return false;
		var winding = 0;
		var j = n - 1;
		for (i in 0...n) {
			var pi = polygon[i];
			var pj = polygon[j];
			if (pj.y <= pt.y) {
				if (pi.y > pt.y && crossSign(pj, pi, pt) > 0)
					winding++;
			} else {
				if (pi.y <= pt.y && crossSign(pj, pi, pt) < 0)
					winding--;
			}
			j = i;
		}
		return winding != 0;
	}

	static function crossSign(a:SVGPoint, b:SVGPoint, c:SVGPoint):Float {
		return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
	}

	static function samePoint(a:SVGPoint, b:SVGPoint):Bool {
		var dx = b.x - a.x;
		var dy = b.y - a.y;
		return dx * dx + dy * dy <= 1e-9;
	}

	static var earcut:hxd.earcut.Earcut = null;

	static function getEarcut():hxd.earcut.Earcut {
		if (earcut == null)
			earcut = new hxd.earcut.Earcut();
		return earcut;
	}
}
