package cgd.debug;

import sys.net.Socket;
import sys.net.Host;
import haxe.Json;
import h2d.Object;
import h2d.Text;
import h2d.Scene;
import h3d.mat.Texture;
import haxe.crypto.Base64;
import sys.thread.Thread;
import hxd.App;

class AgentServer {
    var socket: Socket;
    var thread: Thread;
    var app: App;

    public function new(app: App, port: Int = 8080) {
        this.app = app;
        socket = new Socket();
        socket.bind(new Host("127.0.0.1"), port);
        socket.listen(1);
        
        thread = Thread.create(runThread);
    }

    function runThread():Void {
        while(true) {
            var client = socket.accept();
            if (client == null) continue;
            
            client.setBlocking(true);
            var request = client.input.readLine();
            
            if (request == "GET_SCENE") {
                var sceneData:Dynamic = null;
                var lock = new sys.thread.Lock();
                haxe.MainLoop.runInMainThread(function() {
                    sceneData = dumpNode(app.s2d);
                    lock.release();
                });
                lock.wait();
                client.output.writeString(Json.stringify(sceneData));
            } 
            else if (request == "GET_SCREENSHOT") {
                var bytes:haxe.io.Bytes = null;
                var lock = new sys.thread.Lock();
                haxe.MainLoop.runInMainThread(function() {
                    var tex = new Texture(app.s2d.width, app.s2d.height, [Target]);
                    app.s2d.drawTo(tex);
                    bytes = tex.capturePixels().toPNG();
                    lock.release();
                });
                lock.wait();
                client.output.writeString(Base64.encode(bytes));
            }
            
            client.close();
        }
    }

    function dumpNode(obj: Object): Dynamic {
        var bounds = obj.getBounds();
        var data: Dynamic = {
            name: obj.name != null ? obj.name : Type.getClassName(Type.getClass(obj)),
            x: obj.x, y: obj.y,
            visible: obj.visible,
            bounds: { x: bounds.xMin, y: bounds.yMin, w: bounds.width, h: bounds.height },
            children: []
        };
        
        if (Std.isOfType(obj, Text)) {
            data.text = cast(obj, Text).text;
        }

        for (i in 0...obj.numChildren) {
            data.children.push(dumpNode(obj.getChildAt(i)));
        }
        return data;
    }
}
