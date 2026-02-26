package cgd;

import h2d.Tile;

enum abstract GlobalIcons(String) to String from String {
    //autogenerate from /res/icons (start)
    public static inline var heart_emoji:GlobalIcons = "heart_emoji";
    //autogenerate from /res/icons (end)

    public function toTile():Tile {
        switch(this) {
            //autogenerate mapping to hxd.Res icon item (start)
            case heart_emoji: return hxd.Res.icons.heart_emoji.toTile();
            //autogenerate mapping to hxd.Res icon item (end)
        }
        throw 'Unknown GlobalIcons value: "[object global]"';
    }

    public static function all(): Array<GlobalIcons> {
        return [
            //autogenerate all GlobalIcons values (start)
            heart_emoji
            //autogenerate all GlobalIcons values (end)
        ];
    }
}
