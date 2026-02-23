package cgd;

import h2d.Font;
import hxd.App;
import hxd.Timer;
import cgd.RichTextLibrary.RichTextEffectInstance;

class _RichTextTypecheckMain extends App {
	var rt: RichText;

	static function main() {
		new _RichTextTypecheckMain();
	}

	override function init() {
		var lib = new RichTextLibrary();
		RichText.configurable = lib;

		var font : Font = hxd.res.DefaultFont.get();
		lib.registerFont("default", font);

		lib.registerEffect("wave", function(target) {
			var amp = Std.parseFloat(target.getAttribute("amp", "6"));
			var speed = Std.parseFloat(target.getAttribute("speed", "6"));
			var phase = Std.parseFloat(target.getAttribute("phase", "0.45"));
			return new RichTextEffectInstance(false, null, function(updateTarget, dt, elapsed) {
				for( glyph in updateTarget.glyphs ) {
					var offset = Math.sin(elapsed * speed + glyph.index * phase) * amp;
					glyph.bitmap.y = glyph.baseY + offset;
				}
			});
		});

		rt = new RichText(font, s2d);
		rt.x = 40;
		rt.y = 80;
		rt.fontName = "default";
		rt.text = 'Here is a word doing the wave: <effect name="wave" amp="8" speed="5.5" phase="0.55">WAVE</effect>';
	}

	override function update(dt) {
		super.update(dt);
		@:privateAccess rt.onUpdate(dt);
	}
}