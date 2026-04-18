package cgd.utils;

import cgd.coro.Coroutine;
import cgd.coro.Coroutine.CoroutineBaseFunction;
import cgd.coro.Future;

private typedef TransitionRegistration<TKey> = {
    id:TKey,
    factory:Void->Coroutine
}

private typedef TransitionInvocation<TKey> = {
    id:TKey,
    coroutine:Coroutine,
    completion:Future<Dynamic>
}

enum TransitionRequestResult {
    Started(future:Future);
    Rejected;
}


class TransitionRunner<TKey = String> {
    var transitions: Array<TransitionRegistration<TKey>> = [];
    var currentTransition: TransitionInvocation<TKey> = null;

    public function new() {
    }

    public function add(id: TKey, coro: CoroutineBaseFunction) {
        transitions.push({
            id: id,
            factory: () -> new Coroutine(coro)
        });
    }

    public function tryStart(id: TKey): TransitionRequestResult {
        if (currentTransition != null) {
            return Rejected;
        }

        var reg: TransitionRegistration<TKey> = null;
        for (t in transitions) {
            if (t.id == id) {
                reg = t;
                break;
            }
        }

        if (reg == null) {
            return Rejected;
        }

        var coro = reg.factory();
        var future = coro.future();

        currentTransition = {
            id: reg.id,
            coroutine: coro,
            completion: future
        };

        future.then((_) -> {
            if (currentTransition != null && currentTransition.coroutine == coro) {
                currentTransition = null;
            }
        });

        coro.start();

        return Started(future);
    }

    public function cancel(): Void {
        if (currentTransition != null) {
            cgd.coro.ext.CoroutineExtensions.forceStop(currentTransition.coroutine);
            currentTransition = null;
        }
    }
}
