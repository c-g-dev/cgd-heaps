package coro;

import ludi.commons.UUID;
import coro.Future;

class Task<T = Dynamic> {
	private var uuid: String = UUID.generate();
	private var factory:Void->Future<T>;

	public function new(factory:Void->Future<T>) {
		this.factory = factory;
	}

	public function start():Future<T> {
		trace('Task ${uuid} started');
		return factory();
	}

	public inline function toFuture():Future<T>
		return start();

	public function map<U>(fn:T->U):Task<U> {
		return new Task<U>(() -> start().map(fn));
	}

	public function then<U>(next:T->Task<U>):Task<U> {
		return new Task<U>(() -> {
			var out = new Future<U>();
			start().then((value) -> {
				next(value).start().then((result) -> out.resolve(result));
			});
			return out;
		});
	}

	public function chain<U>(next:T->Task<U>):Task<U> {
		return new Task<U>(() -> {
			var out = new Future<U>();
			start().then((value) -> {
				next(value).start().then((result) -> out.resolve(result));
			});
			return out;
		});
	}

	public static function of<T>(value:T):Task<T> {
		return new Task<T>(() -> Future.of(value));
	}

	public static function fromFuture<T>(future:Future<T>):Task<T> {
		return new Task<T>(() -> future);
	}

	public static function all(tasks:Array<Task>):Task<Array<Dynamic>> {
		return new Task<Array<Dynamic>>(() -> Future.all(tasks.map((t) -> t.start())));
	}

	public static function race(tasks:Array<Task>):Task<Dynamic> {
		return new Task<Dynamic>(() -> Future.race(tasks.map((t) -> t.start())));
	}

	public static function immediate():Task<Dynamic> {
		return new Task<Dynamic>(() -> Future.immediate());
	}

	public static function wrap(cb:Void->Void):Task<Dynamic> {
		return new Task<Dynamic>(() -> Future.wrap(cb));
	}

	public static function sequence(tasks:Array<Task>):Task<Dynamic> {
		if(tasks == null || tasks.length == 0) {
			trace('Task sequence: no tasks');
			return new Task<Dynamic>(() -> Future.immediate());
		}
		var resultTask = tasks[0];
		for(i in 1...tasks.length) {
			resultTask = resultTask.chain((_) -> tasks[i]);
		}
		return resultTask;
	}

}