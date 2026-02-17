# c-g-dev heaps.io fork

## Scoped Resource Loading

One of the biggest issues with heaps.io is that you cannot easily import components that have their own local resources. I have already addressed this in my heaps-local-res repo, but that necessitates a change in resource access syntax.

With this repo you can keep the same normal resource access syntax like:

```
var img = hxd.Res.myImg.toTile();
```

BUT individual folders/packages can have their own /res folders. The /res folder that is used by a class is mapped to the lowest /res folder in its filetree path. 

This requires a full overhaul of the internals of the heaps.io Resource system and cannot easily be ported to its own library. Thus a fork of heaps.io is necessary.

## Object .update() system

Heaps.io objects can only do on-frame processing via sync(). In this fork, Objects now have a dedicated .update() method that is called every frame. If an object is disabled, then the update() of its children is not called. The Scene is the root of all update() calls.

## Planned features

- Fix the Graphics line rendering (heaps.io has had open PRs for years that fix these issues but they never get merged)
- More componentizing support
- Potentially port my ludi coroutine system into this repo directly
- Potentially just port in all of my heaps.io utilities for convinience

