package cgd;

import h2d.Font;

enum abstract GlobalFonts(String) to String from String {
    //autogenerate from /res/fonts (start)
    public static inline var geist_bold:GlobalFonts = "geist_bold";
    public static inline var MPLUS2_Black:GlobalFonts = "MPLUS2_Black";
    public static inline var MPLUS2_Bold:GlobalFonts = "MPLUS2_Bold";
    public static inline var MPLUS2_ExtraBold:GlobalFonts = "MPLUS2_ExtraBold";
    public static inline var MPLUS2_ExtraLight:GlobalFonts = "MPLUS2_ExtraLight";
    public static inline var MPLUS2_Light:GlobalFonts = "MPLUS2_Light";
    public static inline var MPLUS2_Medium:GlobalFonts = "MPLUS2_Medium";
    public static inline var MPLUS2_Regular:GlobalFonts = "MPLUS2_Regular";
    public static inline var MPLUS2_SemiBold:GlobalFonts = "MPLUS2_SemiBold";
    public static inline var MPLUS2_Thin:GlobalFonts = "MPLUS2_Thin";
    public static inline var VL_Gothic_Regular:GlobalFonts = "VL_Gothic_Regular";
    //autogenerate from /res/fonts (end)

    public function toFont():Font {
        switch(this) {
            //autogenerate mapping to hxd.Res font item (start)
            case geist_bold: return hxd.Res.fonts.geist.geist_bold.toFont();
            case MPLUS2_Black: return hxd.Res.fonts.mplus2.MPLUS2_Black.toFont();
            case MPLUS2_Bold: return hxd.Res.fonts.mplus2.MPLUS2_Bold.toFont();
            case MPLUS2_ExtraBold: return hxd.Res.fonts.mplus2.MPLUS2_ExtraBold.toFont();
            case MPLUS2_ExtraLight: return hxd.Res.fonts.mplus2.MPLUS2_ExtraLight.toFont();
            case MPLUS2_Light: return hxd.Res.fonts.mplus2.MPLUS2_Light.toFont();
            case MPLUS2_Medium: return hxd.Res.fonts.mplus2.MPLUS2_Medium.toFont();
            case MPLUS2_Regular: return hxd.Res.fonts.mplus2.MPLUS2_Regular.toFont();
            case MPLUS2_SemiBold: return hxd.Res.fonts.mplus2.MPLUS2_SemiBold.toFont();
            case MPLUS2_Thin: return hxd.Res.fonts.mplus2.MPLUS2_Thin.toFont();
            case VL_Gothic_Regular: return hxd.Res.fonts.vlgothic.VL_Gothic_Regular.toFont();
            //autogenerate mapping to hxd.Res font item (end)
        }
        return hxd.res.DefaultFont.get();
    }
    public static function all(): Array<GlobalFonts> {
        return [
            //autogenerate all GlobalFonts values (start)
            geist_bold,
            MPLUS2_Black,
            MPLUS2_Bold,
            MPLUS2_ExtraBold,
            MPLUS2_ExtraLight,
            MPLUS2_Light,
            MPLUS2_Medium,
            MPLUS2_Regular,
            MPLUS2_SemiBold,
            MPLUS2_Thin,
            VL_Gothic_Regular
            //autogenerate all GlobalFonts values (end)
        ];
    }
}
