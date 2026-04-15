package cgd.debug;

class DequeuedDispatcher {
    static var queue = new sys.thread.Deque<Void->Void>();
    
    public static function runOnMain(func: Void->Void) {
        queue.push(func); // Thread-safe push
    }
    
    // Call this in your App.update(dt) method
    public static function update() {
        var func = queue.pop(false); // Non-blocking pop
        while(func != null) {
            func();
            func = queue.pop(false);
        }
    }
    
}