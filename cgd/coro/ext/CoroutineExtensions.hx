package coro.ext;

import coro.Coroutine;
import coro.Future;
import coro.CoroutineSystem;

@:access(coro.CoroutineContext)
@:access(coro.CoroutineSystem)
@:access(coro.Future)
class CoroutineExtensions {
	public static function start(coroutine:Coroutine):Void {
		if (coroutine.context().hasStarted)
			return;
		CoroutineSystem.MAIN.add(coroutine.context());
	}

	public static function pause(coroutine:Coroutine):Void {
		coroutine.context().manuallyPaused = true;
	}

	public static function forceStop(coroutine:Coroutine):Void {
		CoroutineSystem.MAIN.remove(coroutine.context());
	}

	public static function future(coroutine:Coroutine):Future {
		return coroutine.context().future;
	}
}
