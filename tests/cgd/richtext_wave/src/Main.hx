package ;

import hxd.Key;
import cgd.ui.SuperTextLibrary;
import cgd.ui.SuperText;
import cgd.ui.SuperTextTypewriter;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterDeallocateLinesEffect;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterRequest;
import h2d.Font;
import hxd.App;
import hxd.Timer;
import cgd.ui.SuperTextLibrary.SuperTextEffectInstance;


class Main extends App {
	var st: SuperText;
	var typewriter: SuperTextTypewriter;

	static function main() {
		new Main();
	}

	override function init() {
		var lib = new SuperTextLibrary();
		SuperText.configurable = lib;

		var font : Font = hxd.res.DefaultFont.get();
		lib.registerFont("default", font);

		lib.registerEffect("wave", function(target) {
			var amp = Std.parseFloat(target.getAttribute("amp", "6"));
			var speed = Std.parseFloat(target.getAttribute("speed", "6"));
			var phase = Std.parseFloat(target.getAttribute("phase", "0.45"));
			return new SuperTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
				for( glyph in updateTarget.glyphs ) {
					var offset = Math.sin(elapsed * speed + glyph.index * phase) * amp;
					glyph.bitmap.y = glyph.baseY + offset;
				}
			});
		});

		st = new SuperText(font, s2d);
		st.x = 40;
		st.y = 80;
		st.scale(4);
		st.fontName = "default";
		st.maxWidth = 140;
		st.text = '<p>Here is a word doing the <effect name="wave" amp="8" speed="5.5" phase="0.55">WAVE</effect> effect in paragraph one. Test test test test test test test test test test.</p><p>Paragraph two keeps writing after deallocating lines.</p><p>Paragraph three validates finish flow.</p>';
		typewriter = st.createTypewriter(
			44,
			3,
			WaitForAdvance,
			typewriterController,
			SlideLinesUp(320)
		);
		typewriter.start().then(function(_) {
			trace("Wave smoke test typewriter finished.");
		});
	}

	function typewriterController(state:SuperTextTypewriterOnFrameState):SuperTextTypewriterRequest {
		return switch( state ) {
		case Writing:{ return Wait; }
		case AllLinesAllocated:{ if(Key.isDown(Key.SPACE)) return Advance; else return Wait; }
		case DeallocatingLines:{ return Wait; }
		case ParagraphBreak:{ return if(Key.isDown(Key.SPACE)) Advance; else Wait; }
		case NoMoreParagraphs:{ return Finish; }
		}
	}
}