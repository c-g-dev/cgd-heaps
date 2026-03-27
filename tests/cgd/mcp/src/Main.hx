package;

import hxd.App;
import h2d.Text;
import cgd.debug.AgentServer;
import sys.thread.Thread;
import sys.net.Socket;
import sys.net.Host;
import haxe.Json;

class Main extends App {
    
    static function main() {
        new Main();
    }

    override function init() {
        var font = hxd.res.DefaultFont.get();
        var text = new Text(font, s2d);
        text.text = "Hello MCP!";
        text.name = "TestTextNode";

        // AgentServer is already started by hxd.App in HL builds
        // agentServer = new AgentServer(this, 8080);

        // Run the test in a separate thread so it doesn't block the Heaps main loop
        Thread.create(runTestClient);
    }
    
    function runTestClient() {
        // Wait a bit for the server to bind and the scene to render
        Sys.sleep(1.0);

        trace("=== Testing AgentServer ===");

        trace("Running GET_SCENE test...");
        var socket = new Socket();
        
        socket.connect(new Host("127.0.0.1"), 8080);
        socket.write("GET_SCENE\n");
        var sceneRes = socket.read();
        socket.close();
        
        var sceneJson:Dynamic = Json.parse(sceneRes);

        var foundText = false;
        function findText(node:Dynamic) {
            if (node.name == "TestTextNode" && node.text == "Hello MCP!") {
                foundText = true;
            }
            if (node.children != null) {
                var arr:Array<Dynamic> = node.children;
                for (child in arr) {
                    findText(child);
                }
            }
        }
        findText(sceneJson);
        
        if (foundText) {
            trace("GET_SCENE: SUCCESS");
        } else {
            trace("GET_SCENE: FAILED - Text node not found");
        }

        trace("Running GET_SCREENSHOT test...");
        socket = new Socket();
        socket.connect(new Host("127.0.0.1"), 8080);
        socket.write("GET_SCREENSHOT\n");
        var screenshotRes = socket.read();
        socket.close();

        if (screenshotRes != null && screenshotRes.length > 100) {
            trace("GET_SCREENSHOT: SUCCESS");
        } else {
            trace("GET_SCREENSHOT: FAILED - Screenshot data too small or null");
        }


        trace("=== Testing McpMain JSON-RPC ===");

        var pipeServer = new Socket();
        pipeServer.bind(new Host("127.0.0.1"), 8081);
        pipeServer.listen(1);

        var mcpClientPipe = new Socket();
        mcpClientPipe.connect(new Host("127.0.0.1"), 8081);
        var mcpServerPipe = pipeServer.accept();
        pipeServer.close();

        // Run McpMain in another thread
        Thread.create(function() {
            cgd.cli.mcp.McpMain.run(Sys.getCwd(), Sys.getCwd(), mcpServerPipe.input, mcpServerPipe.output);
        });

        trace("Running MCP initialize test...");
        var initReq = {
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: {}
        };
        mcpClientPipe.output.writeString(Json.stringify(initReq) + "\n");
        var initResStr = mcpClientPipe.input.readLine();
        var initRes:Dynamic = Json.parse(initResStr);
        if (initRes.result != null && initRes.result.serverInfo != null && initRes.result.serverInfo.name == "cgdheaps-mcp") {
            trace("MCP initialize: SUCCESS");
        } else {
            trace("MCP initialize: FAILED");
        }

        trace("Running MCP tools/list test...");
        var listReq = {
            jsonrpc: "2.0",
            id: 2,
            method: "tools/list",
            params: {}
        };
        mcpClientPipe.output.writeString(Json.stringify(listReq) + "\n");
        var listResStr = mcpClientPipe.input.readLine();
        var listRes:Dynamic = Json.parse(listResStr);
        if (listRes.result != null && listRes.result.tools != null && listRes.result.tools.length >= 2) {
            trace("MCP tools/list: SUCCESS");
        } else {
            trace("MCP tools/list: FAILED");
        }

        trace("Running MCP tools/call get_scene_tree test...");
        var callReq = {
            jsonrpc: "2.0",
            id: 3,
            method: "tools/call",
            params: { name: "get_scene_tree", arguments: {} }
        };
        mcpClientPipe.output.writeString(Json.stringify(callReq) + "\n");
        var callResStr = mcpClientPipe.input.readLine();
        var callRes:Dynamic = Json.parse(callResStr);
        if (callRes.result != null && callRes.result.content != null && callRes.result.content[0].type == "text") {
            trace("MCP tools/call get_scene_tree: SUCCESS");
        } else {
            trace("MCP tools/call get_scene_tree: FAILED");
        }

        Sys.exit(0);
    }
}
