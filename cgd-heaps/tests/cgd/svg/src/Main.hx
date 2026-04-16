package;

import cgd.svg.SVG;
import cgd.svg.SVGDocument.SVGFillRule;
import cgd.svg.SVGDocument.SVGStrokeLineCap;
import cgd.svg.SVGDocument.SVGStrokeLineJoin;
import cgd.svg.SVGParser;
import h2d.Graphics;
import h2d.Text;
import hxd.App;
import hxd.Key;

class Main extends App {
	static inline var ASSERT_SOURCE = '<svg viewBox="0 0 10 10" width="20" height="20" fill="none"><g transform="translate(1 2)"><rect x="1" y="1" width="3" height="2" fill="currentColor"/><path d="M2 2 L3 2" stroke="currentColor" stroke-width="1"/></g></svg>';
	static inline var SHOWCASE_SOURCE = '<svg viewBox="0 0 64 64" width="128" height="128" fill="none"><g transform="translate(4 4)"><rect x="4" y="4" width="48" height="48" rx="10" fill="#1B2230" stroke="currentColor" stroke-width="2"/><circle cx="28" cy="28" r="10" fill="currentColor" fill-opacity="0.25" stroke="currentColor" stroke-width="2"/><path d="M16 36 L26 24 L34 30 L42 18" stroke="currentColor" stroke-width="3"/><polyline points="14,18 22,14 28,20 36,12 44,16" stroke="#7DD3FC" stroke-width="2"/><polygon points="18,42 24,48 14,50" fill="#F59E0B"/></g></svg>';

	var statusLabel:Text;

	static function main() {
		
	//	h3d.Engine.ANTIALIASING = 4;
		//sdl.Sdl.setGLOptions(4, 3, 24, 8, sdl.Sdl.DOUBLE_BUFFER | sdl.Sdl.GL_CORE_PROFILE, 4);
	//	sdl.Sdl.setGLAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
	//	sdl.Sdl.setGLAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
		new Main();
	}

	static inline var SDL_GL_MULTISAMPLEBUFFERS = 13;
static inline var SDL_GL_MULTISAMPLESAMPLES = 14;

	override function init() {
		
		trace("Starting SVG tests...");
		runAssertions();
		buildShowcase();
		trace("All SVG tests passed successfully!");
		trace("GL version: " + sdl.GL.getParameter(sdl.GL.VERSION));
		trace("GL renderer: " + sdl.GL.getParameter(sdl.GL.RENDERER));
		trace("GL vendor: " + sdl.GL.getParameter(sdl.GL.VENDOR));

		var sampleBuffers = sdl.Sdl.getGLAttribute(SDL_GL_MULTISAMPLEBUFFERS);
		var samples = sdl.Sdl.getGLAttribute(SDL_GL_MULTISAMPLESAMPLES);
		trace("GL_SAMPLE_BUFFERS = " + sampleBuffers);
		trace("GL_SAMPLES = " + samples);
	}

	override function update(dt:Float) {
		super.update(dt);
		if (Key.isPressed(Key.ESCAPE)) {
			Sys.exit(0);
		}
	}

	function runAssertions() {
		testSvgWrapperStatsAndRedraw();
		testPathImplicitLineTo();
		testStrokeStyleParsingAndMeshRendering();
	}

	function testSvgWrapperStatsAndRedraw() {
		var svg = new SVG();
		svg.currentColor = 0x336699;
		svg.load(ASSERT_SOURCE);

		assertStats(svg.lastStats, 2, 1, 1, 2);
		assertBounds(svg.lastStats, 4, 6, 6, 4);
		assertNear(svg.contentWidth, 6, "Expected contentWidth to reflect rendered bounds");
		assertNear(svg.contentHeight, 4, "Expected contentHeight to reflect rendered bounds");
		if (svg.source != ASSERT_SOURCE) {
			throw "Expected SVG source getter to return the loaded source";
		}

		svg.unitSize = 2;
		assertStats(svg.lastStats, 2, 1, 1, 2);
		assertBounds(svg.lastStats, 8, 12, 12, 8);

		svg.clear();
		if (svg.lastStats != null) {
			throw "Expected clear() to reset lastStats";
		}
		assertNear(svg.contentWidth, 0, "Expected contentWidth to reset to zero after clear()");
		assertNear(svg.contentHeight, 0, "Expected contentHeight to reset to zero after clear()");
	}

	function testPathImplicitLineTo() {
		var parser = new SVGParser();
		parser.setCurrentColor(0x112233);
		var stats = parser.inspect('<svg><path d="M1 1 2 1 2 2 Z" fill="currentColor"/></svg>');
		assertStats(stats, 1, 1, 0, 1);
		assertBounds(stats, 1, 1, 1, 1);
	}

	function testStrokeStyleParsingAndMeshRendering() {
		var parser = new SVGParser();
		var document = parser.parse('<svg><path d="M2 8 L8 8 L8 2" fill="none" stroke="#336699" stroke-width="2" stroke-linejoin="round" stroke-linecap="square" stroke-miterlimit="7"/></svg>');
		if (document.shapes.length != 1) {
			throw 'Expected one parsed shape, got ${document.shapes.length}';
		}
		var style = document.shapes[0].style;
		if (style.fillRule != SVGFillRule.NonZero) {
			throw "Expected default fillRule to remain nonzero";
		}
		if (style.strokeLineJoin != SVGStrokeLineJoin.Round) {
			throw "Expected stroke-linejoin to parse as round";
		}
		if (style.strokeLineCap != SVGStrokeLineCap.Square) {
			throw "Expected stroke-linecap to parse as square";
		}
		assertNear(style.strokeMiterLimit, 7, "Expected stroke-miterlimit to parse");

		var svg = new SVG(null, s2d);
		svg.renderMode = MeshRendering;
		svg.load('<svg viewBox="0 0 12 12"><path d="M2 9 L6 3 L10 9" fill="none" stroke="#FFAA00" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/></svg>');
		assertStats(svg.lastStats, 1, 0, 1, 0);
		if (svg.meshDrawable == null) {
			throw "Expected meshDrawable to be created in mesh render mode";
		}
		if (svg.meshDrawable.vertexCount <= 0) {
			throw "Expected mesh renderer to emit geometry";
		}
	}

	function buildShowcase() {
		var background = new Graphics(s2d);
		background.beginFill(0x0B1020, 1);
		background.drawRect(0, 0, s2d.width, s2d.height);
		background.endFill();

		var panel = new Graphics(s2d);
		panel.beginFill(0x141C2E, 1);
		panel.lineStyle(1, 0x3B82F6, 0.35);
		panel.drawRect(24, 24, 720, 420);
		panel.endFill();

		var title = addLabel("SVG smoke test showcase", 40, 40, 0xFFFFFF, 1.35);
		addLabel("New cgd.svg.SVG object rendering into h2d.Graphics", 40, title.y + 28, 0xA5B4FC, 1.0);
		addLabel("Press ESC to close", 40, title.y + 56, 0x93C5FD, 0.95);

		s2d.defaultSmooth = true;
		var leftSvg = new SVG(SHOWCASE_SOURCE, s2d);
		leftSvg.x = 72;
		leftSvg.y = 132;
		leftSvg.currentColor = 0x60A5FA;
		leftSvg.renderMode = MeshRendering;

		var rightSvg = new SVG(SHOWCASE_SOURCE, s2d);
		rightSvg.x = 392;
		rightSvg.y = 132;
		rightSvg.currentColor = 0xF472B6;
		rightSvg.unitSize = 2;

		addLabel("currentColor = blue, unitSize = 1", 72, 292, 0xBFDBFE, 0.9);
		addLabel("currentColor = pink, unitSize = 2", 392, 292, 0xFBCFE8, 0.9);

		var boundsBox = new Graphics(s2d);
		drawBoundsBox(boundsBox, leftSvg, 0x60A5FA);
		drawBoundsBox(boundsBox, rightSvg, 0xF472B6);

		statusLabel = addLabel("", 40, 360, 0xD1D5DB, 0.95);
		statusLabel.text = [
			'Left bounds: ${fmt(leftSvg.contentWidth)} x ${fmt(leftSvg.contentHeight)}',
			'Right bounds: ${fmt(rightSvg.contentWidth)} x ${fmt(rightSvg.contentHeight)}'
		].join("    ");
	}

	function drawBoundsBox(g:Graphics, svg:SVG, color:Int) {
		if (svg.lastStats == null || svg.lastStats.bounds == null) {
			return;
		}
		var bounds = svg.lastStats.bounds;
		g.lineStyle(1, color, 0.75);
		g.drawRect(svg.x + bounds.x, svg.y + bounds.y, bounds.width, bounds.height);
	}

	function addLabel(text:String, x:Float, y:Float, color:Int, scale:Float):Text {
		var label = new Text(hxd.res.DefaultFont.get(), s2d);
		label.text = text;
		label.textColor = color;
		label.x = x;
		label.y = y;
		label.scale(scale);
		return label;
	}

	function fmt(value:Float):String {
		var rounded = Math.round(value * 10) / 10;
		return Std.string(rounded);
	}

	static function assertStats(stats:Dynamic, shapeCount:Int, filledShapeCount:Int, strokedShapeCount:Int, currentColorUseCount:Int) {
		if (stats == null) {
			throw "Expected stats to be available";
		}
		if (stats.shapeCount != shapeCount) {
			throw 'Expected shapeCount ${shapeCount}, got ${stats.shapeCount}';
		}
		if (stats.filledShapeCount != filledShapeCount) {
			throw 'Expected filledShapeCount ${filledShapeCount}, got ${stats.filledShapeCount}';
		}
		if (stats.strokedShapeCount != strokedShapeCount) {
			throw 'Expected strokedShapeCount ${strokedShapeCount}, got ${stats.strokedShapeCount}';
		}
		if (stats.currentColorUseCount != currentColorUseCount) {
			throw 'Expected currentColorUseCount ${currentColorUseCount}, got ${stats.currentColorUseCount}';
		}
	}

	static function assertBounds(stats:Dynamic, x:Float, y:Float, width:Float, height:Float) {
		if (stats == null || stats.bounds == null) {
			throw "Expected bounds to be available";
		}
		assertNear(stats.bounds.x, x, 'Expected bounds.x ${x}, got ${stats.bounds.x}');
		assertNear(stats.bounds.y, y, 'Expected bounds.y ${y}, got ${stats.bounds.y}');
		assertNear(stats.bounds.width, width, 'Expected bounds.width ${width}, got ${stats.bounds.width}');
		assertNear(stats.bounds.height, height, 'Expected bounds.height ${height}, got ${stats.bounds.height}');
	}

	static function assertNear(actual:Float, expected:Float, message:String) {
		if (Math.abs(actual - expected) > 1e-6) {
			throw message;
		}
	}
}
