package cgd.coro;

import cgd.coro.ds.MaybeReturn;
import cgd.coro.Coroutine.CoroutineContext;
import cgd.coro.CoroutineSystem;
import cgd.coro.Coroutine.CoroutineFunction;
import cgd.coro.ext.CoroutineExtensions;
import cgd.coro.Coroutine.FrameYield;


import haxe.macro.Expr;
import haxe.macro.Context;

import cgd.coro.Coroutine;
import haxe.macro.Expr.ExprOf;



@:access(cgd.coro.CoroutineSystem)
@:access(cgd.coro.CoroutineContext)
class Coro {
    public static function start(coroutine: CoroutineFunction):Coroutine {
        var coro = new Coroutine(coroutine);
        CoroutineExtensions.start(coro);
        return coro;
    }

    public static function defer(coroutine: CoroutineFunction):Coroutine {
        var coro = new Coroutine(coroutine);
        return coro;
    }

    public static function once<T>(callback: MaybeReturn<T>):T {
        var ctx = CoroutineSystem.MAIN.contextStack.peek();
        if (ctx == null) {
            return (callback : Void -> T)();
        }

        return ctx.once(callback);
    }

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

    public static function haltTree(coroutine: Coroutine):Void {
        CoroutineSystem.MAIN.haltTree(coroutine.context());
    }

    public static macro function step(block:Expr):Expr {
        switch (block.expr) {
            case EBlock(_):
                return macro cgd.coro.Coro.start((_) -> $block);
            case _:
                Context.error("Coro.step expects a block expression: Coro.step({ ... })", block.pos);
        }
        return macro null;
    }

	    public static macro function tween(object:Expr, duration:Expr, fields:Expr):Expr {
	    	var pos = Context.currentPos();
	    	switch (fields.expr) {
	    		case EObjectDecl(objFields):
	    			var dataObjectFields:Array<{ field:String, expr:Expr, quotes:Null<haxe.macro.Expr.QuoteStatus> }> = [];
	    			dataObjectFields.push({ field: "startTime", expr: macro haxe.Timer.stamp(), quotes: null });
	    			var assignRunning:Array<Expr> = [];
	    			var assignFinal:Array<Expr> = [];
	    			for (f in objFields) {
	    				var fieldName = f.field;
	    				var objField:Expr = { expr: EField(macro __obj, fieldName), pos: pos };
	    				var startFieldName = "start_" + fieldName;
	    				var deltaFieldName = "delta_" + fieldName;
	    				dataObjectFields.push({ field: startFieldName, expr: objField, quotes: null });
	    				dataObjectFields.push({ field: deltaFieldName, expr: macro ${f.expr} - ${objField}, quotes: null });
	    				var twExpr:Expr = macro __tw;
	    				var startFieldExpr:Expr = { expr: EField(twExpr, startFieldName), pos: pos };
	    				var deltaFieldExpr:Expr = { expr: EField(twExpr, deltaFieldName), pos: pos };
	    				assignRunning.push(macro ${objField} = ${startFieldExpr} + ${deltaFieldExpr} * __t);
	    				assignFinal.push(macro ${objField} = ${startFieldExpr} + ${deltaFieldExpr});
	    			}

	    			var dataObj:Expr = { expr: EObjectDecl(dataObjectFields), pos: pos };

	    			return macro cgd.coro.Coro.start((ctx) -> {
	    				var __obj = cgd.coro.Coro.once(() -> return $object);
	    				var __duration:Float = cgd.coro.Coro.once(() -> return $duration);
	    				var __tw = cgd.coro.Coro.once(() -> return $dataObj);

	    				if (__duration <= 0) {
	    					${{ expr: EBlock(assignFinal), pos: pos }}
	    					return cgd.coro.Coroutine.FrameYield.Stop;
	    				}

	    				var __t:Float = (haxe.Timer.stamp() - __tw.startTime) / __duration;
	    				if (__t >= 1) {
	    					${{ expr: EBlock(assignFinal), pos: pos }}
	    					return cgd.coro.Coroutine.FrameYield.Stop;
	    				}

	    				${{ expr: EBlock(assignRunning), pos: pos }}
	    				return cgd.coro.Coroutine.FrameYield.WaitNextFrame;
	    			});
	    		case _:
	    			Context.error("Coro.tween expects an object literal for fields, e.g., {x: 10, y: 20}", pos);
	    	}
	    	return macro null;
	    }

}