package cgd.coro.macros;

import haxe.macro.Expr;
import coro.Coroutine.FrameYield;

import haxe.macro.Expr.ExprOf;


class FrameYieldMacroExtensions {

    public static macro function yield(callingExpr:ExprOf<FrameYield>):Expr {
        return macro {
            if(!coro.CoroUtils.hasNextOnce()){
                return coro.Coro.once(() -> return $callingExpr);
            }
            else {
                coro.CoroUtils.incrementOnce();
            }
        }
    }

}