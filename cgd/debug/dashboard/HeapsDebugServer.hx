package cgd.debug.dashboard;

import cgd.debug.dashboard.server.endpoints.ClearHighlight;
import cgd.debug.dashboard.server.endpoints.Dashboard;
import cgd.debug.dashboard.server.endpoints.EvalHScript;
import cgd.debug.dashboard.server.endpoints.GetSceneDom2D;
import cgd.debug.dashboard.server.endpoints.HighlightObject;
import cgd.debug.dashboard.server.endpoints.ManualEditObject;
import cgd.debug.dashboard.server.endpoints.ServeUI;
import h2d.Object;
import h2d.Scene;
import haxe.Json;
import StringBuf;
import haxe.io.Bytes;
import StringTools;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;

typedef HeapsDebugRequest = {
	var method:String;
	var path:String;
	var headers:Map<String,String>;
	var body:String;
}

typedef HeapsDebugResponse = {
	var status:Int;
	var contentType:String;
	var body:String;
}


typedef SceneObjectRegistry = {
    var idToObject: Map<String, h2d.Object>;
    var objectToId: Map<h2d.Object, String>;
}

interface IHeapsDebugEndpoint {
    public var method(default, null): String;
    public var path(default, null): String;
    public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse;
}


class HeapsDebugServer {
    static inline var MAX_HEADER_BYTES:Int = 64 * 1024;
    static var instance: HeapsDebugServer;
    static var routes: Map<String, IHeapsDebugEndpoint> = new Map();

    static var appRef: hxd.App;

    static var lastScene2DRegistry: SceneObjectRegistry;

    var port: Int;
    var listenHost: String;
    var listenSocket: Socket;
    var serverThread: Thread;

    public function new(app: hxd.App, port: Int, host: String) {
        appRef = app;
        this.port = port;
        this.listenHost = host;
    }

    
    public static function attach(app: hxd.App, port: Int = 8025, host: String = "127.0.0.1"): Void {
        if (instance == null) {
            instance = new HeapsDebugServer(app, port, host);
            instance.start(app);
        }
    }

    
    public static function registerEndpoint(endpoint: IHeapsDebugEndpoint): Void {
        var key = endpoint.method + " " + endpoint.path;
        routes.set(key, endpoint);
    }

    
    public static inline function getApp(): hxd.App {
        return appRef;
    }

    
    public static inline function setLastScene2DRegistry(registry: SceneObjectRegistry): Void {
        lastScene2DRegistry = registry;
    }

    
    public static inline function getLastScene2DRegistry(): SceneObjectRegistry {
        if(lastScene2DRegistry == null) {
            
            var sr = GetSceneDom2D.getRegistry();
            lastScene2DRegistry = sr.registry;
        }
        return lastScene2DRegistry;
    }

    function start(app: hxd.App): Void {
        initDefaultEndpoints();

        listenSocket = new Socket();
        var host = new Host(listenHost);
        listenSocket.bind(host, port);
        listenSocket.listen(50);

        serverThread = Thread.create(handleAcceptLoop);
    }

    
    public static function stop(): Void {
        if (instance != null) {
            instance.shutdown();
            instance = null;
        }
    }

    function shutdown(): Void {
        if (listenSocket != null) listenSocket.close();
    }

    function handleAcceptLoop(): Void {
        while (true) {
            var client = listenSocket.accept();
            if (client == null) continue;
            Thread.create(function() handleClient(client));
        }
    }

    function handleClient(client: Socket): Void {
        var req = readRequest(client);
        if (req == null) {
            client.close();
            return;
        }
        var res = routeRequest(req);
        writeResponse(client, res);
        client.close();
    }

    function readRequest(client: Socket): Null<HeapsDebugRequest> {
        #if hl
        return readRequestHl(client);
        #else
        var input = client.input;
        var requestLine = input.readLine();
        var parts = requestLine.split(" ");
        if (parts.length < 2) {
            return null;
        }
        var method = parts[0];
        var rawPath = parts[1];
        var qIdx = rawPath.indexOf("?");
        var path = qIdx >= 0 ? rawPath.substr(0, qIdx) : rawPath;

        var headers: Map<String,String> = new Map();
        while (true) {
            var line = input.readLine();
            if (line == null || line == "") break;
            var idx = line.indexOf(":");
            if (idx > 0) {
                var key = StringTools.trim(line.substr(0, idx));
                var value = StringTools.trim(line.substr(idx + 1));
                headers.set(key.toLowerCase(), value);
            }
        }

        var body = "";
        if (headers.exists("content-length")) {
            var len = Std.parseInt(headers.get("content-length"));
            if (len > 0) {
                body = input.readString(len);
            }
        }

        return {
            method: method,
            path: path,
            headers: headers,
            body: body
        };
        #end
    }

    #if hl
    function readRequestHl(client: Socket): Null<HeapsDebugRequest> {
        var requestLine = readSocketLineHl(client);
        if (requestLine == null || requestLine == "") {
            return null;
        }

        var parts = requestLine.split(" ");
        if (parts.length < 2) {
            return null;
        }
        var method = parts[0];
        var rawPath = parts[1];
        var qIdx = rawPath.indexOf("?");
        var path = qIdx >= 0 ? rawPath.substr(0, qIdx) : rawPath;

        var headers: Map<String, String> = new Map();
        var headerBytesRead = requestLine.length;
        while (true) {
            var line = readSocketLineHl(client);
            if (line == null) {
                return null;
            }
            if (line == "") {
                break;
            }
            headerBytesRead += line.length;
            if (headerBytesRead > MAX_HEADER_BYTES) {
                return null;
            }
            var idx = line.indexOf(":");
            if (idx > 0) {
                var key = StringTools.trim(line.substr(0, idx));
                var value = StringTools.trim(line.substr(idx + 1));
                headers.set(key.toLowerCase(), value);
            }
        }

        var body = "";
        if (headers.exists("content-length")) {
            var len = Std.parseInt(headers.get("content-length"));
            if (len > 0) {
                body = readSocketExactStringHl(client, len);
            }
        }

        return {
            method: method,
            path: path,
            headers: headers,
            body: body
        };
    }

    function readSocketLineHl(client: Socket): Null<String> {
        var out = new StringBuf();
        var one = Bytes.alloc(1);
        var readAny = false;
        while (true) {
            var r = socket_recv(
                @:privateAccess client.__s,
                one.getData().bytes,
                0,
                1
            );
            if (r == 0) {
                return readAny ? out.toString() : null;
            }
            if (r < 0) {
                return readAny ? out.toString() : null;
            }

            readAny = true;
            var c = one.get(0);
            if (c == 10) {
                var s = out.toString();
                if (s.length > 0 && s.charCodeAt(s.length - 1) == 13) {
                    s = s.substr(0, s.length - 1);
                }
                return s;
            }
            out.addChar(c);
        }
        return null;
    }

    function readSocketExactStringHl(client: Socket, len: Int): String {
        if (len <= 0) {
            return "";
        }
        var bytes = Bytes.alloc(len);
        var pos = 0;
        while (pos < len) {
            var r = socket_recv(
                @:privateAccess client.__s,
                bytes.getData().bytes,
                pos,
                len - pos
            );
            if (r <= 0) {
                break;
            }
            pos += r;
        }
        return bytes.sub(0, pos).toString();
    }

    @:hlNative("std", "socket_recv")
    static function socket_recv(s: sys.net.SocketHandle, bytes: hl.Bytes, pos: Int, len: Int): Int {
        return 0;
    }
    #end

    function routeRequest(req: HeapsDebugRequest): HeapsDebugResponse {
        var key = req.method + " " + req.path;
        if (routes.exists(key)) {
            return routes.get(key).handle(this, req);
        } else {
            return {
                status: 404,
                contentType: "text/plain; charset=utf-8",
                body: "Not found"
            };
        }
    }

    function writeResponse(client: Socket, res: HeapsDebugResponse): Void {
        var output = client.output;
        var bodyBytes = haxe.io.Bytes.ofString(res.body);
        var sb = new StringBuf();
        sb.add("HTTP/1.1 "); sb.add(Std.string(res.status)); sb.add(" "); sb.add(statusText(res.status)); sb.add("\r\n");
        sb.add("Content-Type: "); sb.add(res.contentType); sb.add("\r\n");
        sb.add("Content-Length: "); sb.add(Std.string(bodyBytes.length)); sb.add("\r\n");
        sb.add("Connection: close\r\n");
        sb.add("\r\n");
        output.writeString(sb.toString());
        output.write(bodyBytes);
        output.flush();
    }

    function statusText(code: Int): String {
        return switch (code) {
            case 200: "OK";
            case 400: "Bad Request";
            case 404: "Not Found";
            case 500: "Internal Server Error";
            default: "OK";
        };
    }

    function initDefaultEndpoints(): Void {
        GetSceneDom2D.register();
        Dashboard.register();
        EvalHScript.register();
        ServeUI.register();
        HighlightObject.register();
        ClearHighlight.register();
        ManualEditObject.register();
    }
}

