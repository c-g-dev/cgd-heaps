package cgd.cli.mcp;

import haxe.Json;
import sys.net.Socket;
import sys.net.Host;

class McpMain {
    public static function run(callerCwd:String, libraryRoot:String, ?customStdin:haxe.io.Input, ?customStdout:haxe.io.Output):Void {
        var stdin = customStdin != null ? customStdin : Sys.stdin();
        var stdout = customStdout != null ? customStdout : Sys.stdout();

        while (true) {
            var line = stdin.readLine();
            var req:Dynamic = Json.parse(line);

            if (req.method == "initialize") {
                sendResponse(stdout, req.id, {
                    protocolVersion: "2024-11-05",
                    capabilities: {},
                    serverInfo: { name: "cgdheaps-mcp", version: "1.0.0" }
                });
            } else if (req.method == "tools/list") {
                sendResponse(stdout, req.id, {
                    tools: [
                        {
                            name: "get_scene_tree",
                            description: "Gets the Heaps 2D scene graph (JSON), including text and bounds.",
                            inputSchema: { type: "object", properties: {} }
                        },
                        {
                            name: "get_screenshot",
                            description: "Captures the current screen of the game to visually review UI.",
                            inputSchema: { type: "object", properties: {} }
                        },
                        {
                            name: "execute_hscript",
                            description: "Executes arbitrary hscript code on the connected Heaps application main thread. Has access to 'app', 's2d', and 's3d' variables.",
                            inputSchema: {
                                type: "object",
                                properties: {
                                    code: {
                                        type: "string",
                                        description: "The hscript code to execute"
                                    }
                                },
                                required: ["code"]
                            }
                        }
                    ]
                });
            } else if (req.method == "tools/call") {
                if (req.params.name == "get_scene_tree") {
                    var data = requestFromGame("GET_SCENE");
                    sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
                } else if (req.params.name == "get_screenshot") {
                    var data = requestFromGame("GET_SCREENSHOT");
                    sendResponse(stdout, req.id, { content: [{ type: "image", data: data, mimeType: "image/png" }] });
                } else if (req.params.name == "execute_hscript") {
                    var code:String = req.params.arguments.code;
                    var codeBase64 = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(code));
                    var data = requestFromGame("EXECUTE_HSCRIPT:" + codeBase64);
                    sendResponse(stdout, req.id, { content: [{ type: "text", text: data }] });
                } else {
                    sendResponse(stdout, req.id, { isError: true, content: [{ type: "text", text: "Tool not found" }] });
                }
            } else if (req.method == "notifications/initialized") {
          
            } else {

            }
        }
    }

    static function sendResponse(stdout:haxe.io.Output, id:Dynamic, result:Dynamic):Void {
        var res = { jsonrpc: "2.0", id: id, result: result };
        stdout.writeString(Json.stringify(res) + "\n");
        stdout.flush();
    }

    static function requestFromGame(command:String):String {
        var socket = new Socket();
        socket.connect(new Host("127.0.0.1"), 8080);
        socket.write(command + "\n");
        var result = socket.read();
        socket.close();
        return result;
    }
}
