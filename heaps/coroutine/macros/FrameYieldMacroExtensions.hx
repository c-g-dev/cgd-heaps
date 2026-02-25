package heaps.coroutine.macros;

import haxe.macro.Expr;
import heaps.coroutine.Coroutine.FrameYield;

import haxe.macro.Expr.ExprOf;


class FrameYieldMacroExtensions {

    public static macro function yield(callingExpr:ExprOf<FrameYield>):Expr {
        return macro {
            if(!heaps.coroutine.Coroutine.CoroUtils.hasNextOnce()){
                return heaps.coroutine.Coro.once(() -> return $callingExpr);
            }
            else {
                heaps.coroutine.Coroutine.CoroUtils.incrementOnce();
            }
        }
    }

}
