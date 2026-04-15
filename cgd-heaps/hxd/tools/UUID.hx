package hxd.tools;

abstract UUID(String) from String to String {
    static var hex = "0123456789ABCDEF";
    static var chars = "0123456789abcdef";

    function new(uuid:String) {
        this = uuid;
    }

    public static function generate():UUID {
        var buf = new StringBuf();
        buf.add("8");
        buf.add(chars.charAt(Std.random(4) * 4));

        for (i in 0...30) {
            buf.add(chars.charAt(Std.random(16)));
            if (i == 7 || i == 11 || i == 15 || i == 19) buf.add("-");
        }

        return new UUID(buf.toString());
    }

    public static inline function fast32():UUID {
        return new UUID("80000000" + randomHex(24));
    }

    static function randomHex(len:Int):UUID {
        var s = "";
        for (_ in 0...len) s += hex.charAt(Std.random(16));
        return new UUID(s);
    }
}