package cgd.coro;

//the purpose of this class is to provide a single object where on-frame callbacks can be dropped in to be run in a single coroutine
//thus we can start/stop/manage all of these callbacks in a single object
import cgd.coro.Coroutine;
import cgd.coro.Coroutine.CoroutineContext;
import cgd.coro.Coroutine.FrameYield;
import cgd.coro.ext.CoroutineExtensions;

typedef CoroHostCallback = Float -> Void;

class CoroHost {
	private var callbacks:Array<CoroHostCallback> = [];
	private var coroutine:Coroutine;

	public var isRunning(get, never):Bool;

	public function new() {}

	public function add(callback:CoroHostCallback):Void {
		if (callback == null || callbacks.indexOf(callback) != -1) return;
		callbacks.push(callback);
		start();
	}

	public function remove(callback:CoroHostCallback):Bool {
		var idx = callbacks.indexOf(callback);
		if (idx == -1) return false;

		callbacks.splice(idx, 1);
		return true;
	}

	public function clear():Void {
		callbacks = [];
	}

	public function start():Void {
		if (coroutine != null && !coroutine.context().isComplete) return;

		if (callbacks.length == 0) return;
		coroutine = new Coroutine(onFrame);
		CoroutineExtensions.start(coroutine);
	}

	public function stop():Void {
		if (coroutine == null || coroutine.context().isComplete) return;
		CoroutineExtensions.forceStop(coroutine);
		coroutine = null;
	}

	private function onFrame(ctx:CoroutineContext):FrameYield {
		if (callbacks.length == 0) return Stop;

		var dt = ctx.dt;
		var running = callbacks.copy();
		for (callback in running) {
			callback(dt);
		}
		return WaitNextFrame;
	}

	function get_isRunning():Bool {
		return coroutine != null && !coroutine.context().isComplete;
	}
}