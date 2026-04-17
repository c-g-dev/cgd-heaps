package cgd.coro.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
import cgd.coro.Coroutine.CoroutineContext;

import cgd.coro.Coroutine;
import haxe.macro.Expr.ExprOf;


class CoroutineMacroExtensions {
	public static macro function await<T>(callingExpr:ExprOf<Coroutine<T>>):Expr {
		var expected = Context.getExpectedType();
		var valueNeeded = switch (expected) {
			case null: false;
			default: true;
		};

		if (!valueNeeded) {
			return macro {
				var __coro = cgd.coro.Coro.once(() -> { return $callingExpr;});
				coro.ext.CoroutineExtensions.start(__coro);
				if (!coro.Coroutine.CoroUtils.isComplete(__coro))
					return coro.FrameYield.Suspend(cgd.coro.Coroutine.CoroUtils.getFuture(__coro));
			};
		} else {
			return macro {
				var __coro = cgd.coro.Coro.once(() -> return $callingExpr);
				coro.ext.CoroutineExtensions.start(__coro);
				var __awaitResult:Dynamic = null;

				if (!coro.Coroutine.CoroUtils.isComplete(__coro)) {
					return coro.FrameYield.Suspend(cgd.coro.Coroutine.CoroUtils.getFuture(__coro));
				} else {
					__awaitResult = cgd.coro.Coroutine.CoroUtils.getResult(__coro);
				}

				__awaitResult;
			};
		}
	}

	public static macro function store<T>(ctxExpr:ExprOf<CoroutineContext<T>>, variable:Expr):Expr {
		var name = switch (variable.expr) {
			case EConst(CIdent(n)): n;
			default: Context.error("ctx.store expects an identifier", variable.pos);
		};
		return macro $ctxExpr.setData($v{"__" + name}, $variable);
	}

	public static macro function unstore<T>(ctxExpr:ExprOf<CoroutineContext<T>>, variable:Expr):Expr {
		var name = switch (variable.expr) {
			case EConst(CIdent(n)): n;
			default: Context.error("ctx.unstore expects an identifier", variable.pos);
		};
		var pos = variable.pos;
		var getExpr:Expr = macro $ctxExpr.getData($v{"__" + name});
		var declareExpr:Expr = {
			expr: EVars([
				{name: name, type: null, expr: getExpr}
			]),
			pos: pos
		};
		return { expr: EBlock([declareExpr]), pos: pos };
	}
}
