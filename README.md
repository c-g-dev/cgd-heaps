# c-g-dev heaps.io fork

## Scoped Resource Loading

One of the biggest issues with heaps.io is that you cannot easily import components that have their own local resources. I have already addressed this in my heaps-local-res repo, but that necessitates a change in resource access syntax.

With this repo you can keep the same normal resource access syntax like:

```
var img = hxd.Res.myImg.toTile();
```

BUT individual folders/packages can have their own /res folders. The /res folder that is used by a class is mapped to the lowest /res folder in its filetree path. 

This requires a full overhaul of the internals of the heaps.io Resource system and cannot easily be ported to its own library. Thus a fork of heaps.io is necessary.