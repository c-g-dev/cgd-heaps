package cgd.svg;

enum SVGFillRule {
	NonZero;
	EvenOdd;
}

enum SVGStrokeLineJoin {
	Miter;
	Round;
	Bevel;
}

enum SVGStrokeLineCap {
	Butt;
	Round;
	Square;
}

typedef SVGPoint = {
	var x:Float;
	var y:Float;
}

typedef SVGPolyline = {
	var points:Array<SVGPoint>;
	var closed:Bool;
}

typedef SVGRenderBounds = {
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
}

typedef SVGRenderStats = {
	var nodeCount:Int;
	var shapeCount:Int;
	var subpathCount:Int;
	var filledShapeCount:Int;
	var strokedShapeCount:Int;
	var currentColorUseCount:Int;
	var bounds:Null<SVGRenderBounds>;
}

typedef SVGNodeStyle = {
	var color:Int;
	var fill:Null<Int>;
	var stroke:Null<Int>;
	var strokeWidth:Float;
	var opacity:Float;
	var fillOpacity:Float;
	var strokeOpacity:Float;
	var fillRule:SVGFillRule;
	var strokeLineJoin:SVGStrokeLineJoin;
	var strokeLineCap:SVGStrokeLineCap;
	var strokeMiterLimit:Float;
}

typedef SVGShape = {
	var polylines:Array<SVGPolyline>;
	var style:SVGNodeStyle;
}

class SVGDocument {
	public var shapes(default, null):Array<SVGShape>;
	public var stats(default, null):SVGRenderStats;

	public function new(shapes:Array<SVGShape>, stats:SVGRenderStats) {
		this.shapes = shapes;
		this.stats = stats;
	}

	public static function createEmptyStats():SVGRenderStats {
		return {
			nodeCount: 0,
			shapeCount: 0,
			subpathCount: 0,
			filledShapeCount: 0,
			strokedShapeCount: 0,
			currentColorUseCount: 0,
			bounds: null
		};
	}

	public static function cloneStyle(style:SVGNodeStyle):SVGNodeStyle {
		return {
			color: style.color,
			fill: style.fill,
			stroke: style.stroke,
			strokeWidth: style.strokeWidth,
			opacity: style.opacity,
			fillOpacity: style.fillOpacity,
			strokeOpacity: style.strokeOpacity,
			fillRule: style.fillRule,
			strokeLineJoin: style.strokeLineJoin,
			strokeLineCap: style.strokeLineCap,
			strokeMiterLimit: style.strokeMiterLimit
		};
	}

	public static function scaleStats(stats:SVGRenderStats, unitSize:Int):SVGRenderStats {
		var bounds = stats.bounds;
		return {
			nodeCount: stats.nodeCount,
			shapeCount: stats.shapeCount,
			subpathCount: stats.subpathCount,
			filledShapeCount: stats.filledShapeCount,
			strokedShapeCount: stats.strokedShapeCount,
			currentColorUseCount: stats.currentColorUseCount,
			bounds: bounds == null ? null : {
				x: bounds.x * unitSize,
				y: bounds.y * unitSize,
				width: bounds.width * unitSize,
				height: bounds.height * unitSize
			}
		};
	}
}
