package cgd;

import cgd.ui.SuperTextLibrary.SuperTextEffectInstance;
import cgd.ui.SuperTextLibrary;
import cgd.ui.SuperText;
import cgd.ui.SuperTextTypewriter;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterDeallocateLinesEffect;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterOnFrameState;
import cgd.ui.SuperTextTypewriter.SuperTextTypewriterRequest;
import h2d.Font;
import hxd.App;

class _SuperTextTypecheckMain extends App {
	var st: SuperText;
	var typewriter: SuperTextTypewriter;

	static function main() {
		new _SuperTextTypecheckMain();
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
		st.fontName = "default";
		st.maxWidth = 260;
		st.text = '<p>Here is a word doing the wave: <effect name="wave" amp="8" speed="5.5" phase="0.55">WAVE</effect>. This line should wrap naturally.</p><p>This second paragraph verifies paragraph breaks and line deallocation.</p><p>Last paragraph. Controller will send Finish when done.</p>';

		typewriter = st.createTypewriter(
			42,
			2,
			WaitForAdvance,
			typewriterController,
			SlideLinesUp(240)
		);
		typewriter.start().then(function(_) {
			trace("SuperText typewriter finished.");
		});
	}

	function typewriterController(state:SuperTextTypewriterOnFrameState):SuperTextTypewriterRequest {
		return switch( state ) {
		case Writing:
			Wait;
		case AllLinesAllocated:
			trace("Typewriter state: AllLinesAllocated -> Advance");
			Advance;
		case DeallocatingLines:
			Wait;
		case ParagraphBreak:
			trace("Typewriter state: ParagraphBreak -> Advance");
			Advance;
		case NoMoreParagraphs:
			Finish;
		}
	}

	override function update(dt) {
		super.update(dt);
		st.updateSuperText(dt);
	}
}
