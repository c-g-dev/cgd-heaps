package cgd.coro.macros;

import haxe.macro.Expr;
import cgd.coro.Coroutine.FrameYield;

import haxe.macro.Expr.ExprOf;


class FrameYieldMacroExtensions {

    public static macro function yield(callingExpr:ExprOf<FrameYield>):Expr {
        return macro {
            if(!cgd.coro.Coroutine.CoroUtils.hasNextOnce()){
                return cgd.coro.Coro.once(() -> return $callingExpr);
            }
            else {
                cgd.coro.Coroutine.CoroUtils.incrementOnce();
            }
        }
    }

}