package cgd.ui;

import h2d.Object;
import hxd.Key;

interface INavInputProvider {
    function isUpPressed():Bool;
    function isDownPressed():Bool;
    function isLeftPressed():Bool;
    function isRightPressed():Bool;
    function isConfirmPressed():Bool;
}

class DefaultNavInputProvider implements INavInputProvider {
    public function new() {}

    public function isUpPressed():Bool {
        return Key.isPressed(Key.UP);
    }

    public function isDownPressed():Bool {
        return Key.isPressed(Key.DOWN);
    }

    public function isLeftPressed():Bool {
        return Key.isPressed(Key.LEFT);
    }

    public function isRightPressed():Bool {
        return Key.isPressed(Key.RIGHT);
    }

    public function isConfirmPressed():Bool {
        return Key.isPressed(Key.ENTER);
    }
}

enum NavEvent {
    Leave;
    Enter;
    Selected;
}

enum NavDirection {
    Up;
    Down;
    Left;
    Right;
}

class NavNode<T> {
    public var object(default, null):Object;
    public var data(default, null):Null<T>;

    var onEventCallback:NavEvent -> Void;

    public function new(object:Object, onEvent:NavEvent -> Void, ?data:T) {
        if( object == null ) throw "NavNode requires a non-null object.";
        if( onEvent == null ) throw "NavNode requires a non-null onEvent callback.";
        this.object = object;
        this.data = data;
        this.onEventCallback = onEvent;
    }

    public function onEvent(event:NavEvent):Void {
        onEventCallback(event);
    }
}

class Nav {
    var nodes:Map<Object, NavNode<Dynamic>>;
    var currentSelection:Object;
    var inputProvider:Null<INavInputProvider>;

    public function new(?inputProvider:INavInputProvider) {
        nodes = [];
        currentSelection = null;
        this.inputProvider = inputProvider;
    }

    public function bind<T>(object:Object, onEvent:NavEvent -> Void, ?data:T):NavNode<T> {
        if( object == null ) throw "Nav.bind requires a non-null object.";
        if( onEvent == null ) throw "Nav.bind requires a non-null onEvent callback.";

        var node = new NavNode<T>(object, onEvent, data);
        nodes.set(object, cast node);

        if( currentSelection == null ) {
            currentSelection = object;
            node.onEvent(Enter);
        }

        return node;
    }

    public function clear():Void {
        nodes = [];
        currentSelection = null;
    }

    public function unbind(object:Object):Void {
        if( object == null ) return;
        if( !nodes.exists(object) ) return;

        if( currentSelection == object )
            currentSelection = null;

        nodes.remove(object);
    }

    public function getCurrentSelection():Object {
        return currentSelection;
    }

    public function setSelection(object:Object):Bool {
        if( object == null ) {
            if( currentSelection == null ) return false;
            var previous = nodes.get(currentSelection);
            if( previous != null ) previous.onEvent(Leave);
            currentSelection = null;
            return true;
        }

        if( !nodes.exists(object) )
            throw "Nav.setSelection received an object that is not bound.";

        if( currentSelection == object )
            return false;

        if( currentSelection != null ) {
            var previous = nodes.get(currentSelection);
            if( previous != null ) previous.onEvent(Leave);
        }

        currentSelection = object;
        var next = nodes.get(object);
        if( next != null ) next.onEvent(Enter);
        return true;
    }

    public function move(direction:NavDirection):Bool {
        var next = getNextItem(direction);
        if( next == null ) return false;
        return setSelection(next);
    }

    public inline function moveUp():Bool {
        return move(Up);
    }

    public inline function moveDown():Bool {
        return move(Down);
    }

    public inline function moveLeft():Bool {
        return move(Left);
    }

    public inline function moveRight():Bool {
        return move(Right);
    }

    public function selectCurrent():Bool {
        if( currentSelection == null ) return false;
        var node = nodes.get(currentSelection);
        if( node == null ) return false;
        node.onEvent(Selected);
        return true;
    }

    public function setInputProvider(provider:INavInputProvider):Void {
        inputProvider = provider;
    }

    public function getInputProvider():Null<INavInputProvider> {
        return inputProvider;
    }

    public function update():Void {
        if( inputProvider == null ) return;

        if( inputProvider.isRightPressed() ) {
            moveRight();
            return;
        }

        if( inputProvider.isLeftPressed() ) {
            moveLeft();
            return;
        }

        if( inputProvider.isDownPressed() ) {
            moveDown();
            return;
        }

        if( inputProvider.isUpPressed() ) {
            moveUp();
            return;
        }

        if( inputProvider.isConfirmPressed() )
            selectCurrent();
    }

    function getNextItem(direction:NavDirection):Object {
        if( currentSelection == null )
            return null;

        var currentPos = currentSelection.getAbsPos();
        var cx = currentPos.x;
        var cy = currentPos.y;

        var best:Object = null;
        var bestScore:Float = Math.POSITIVE_INFINITY;

        for( object in nodes.keys() ) {
            if( object == currentSelection )
                continue;

            var pos = object.getAbsPos();
            var x = pos.x;
            var y = pos.y;
            var score1:Float;
            var score2:Float;

            switch( direction ) {
            case Right:
                if( x <= cx ) continue;
                score1 = Math.abs(y - cy);
                score2 = x - cx;
            case Left:
                if( x >= cx ) continue;
                score1 = Math.abs(y - cy);
                score2 = cx - x;
            case Down:
                if( y <= cy ) continue;
                score1 = Math.abs(x - cx);
                score2 = y - cy;
            case Up:
                if( y >= cy ) continue;
                score1 = Math.abs(x - cx);
                score2 = cy - y;
            }

            var score = score2 + (score1 * 2.5);
            if( score < bestScore ) {
                best = object;
                bestScore = score;
            }
        }

        return best;
    }
}
