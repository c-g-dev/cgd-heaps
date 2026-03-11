package cgd.coro.macros;

import cgd.coro.Future;
import haxe.macro.Expr;
import haxe.macro.Context;

import haxe.macro.Expr.ExprOf;


class FutureMacroExtensions {


	public static macro function await<T>(callingExpr:ExprOf<Future<T>>):Expr {
		var expected = Context.getExpectedType();
		var valueNeeded = switch (expected) {
			case null: false;
			default: true;
		};

		if (!valueNeeded) {
			return macro {
				var __future = cgd.coro.Coro.once(() -> {return $callingExpr;});
				if (!__future.isComplete)
					return cgd.coro.Coroutine.FrameYield.Suspend(__future);
			};
		} else {
			return macro {
				var __future = cgd.coro.Coro.once(() -> return $callingExpr);

				var __awaitResult:Dynamic = null;

				if (!__future.isComplete) {
					return cgd.coro.Coroutine.FrameYield.Suspend(__future);
				} else {
					@:privateAccess __awaitResult = __future._result;
				}

				__awaitResult;
			};
		}
	}
}
