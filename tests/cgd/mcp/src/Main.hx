package;

import hxd.App;
import h2d.Text;
import sys.thread.Thread;
import sys.net.Socket;
import sys.net.Host;
import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;

class Main extends App {

	static function main() {
		new Main();
	}

	override function init() {
		var font = hxd.res.DefaultFont.get();
		var text = new Text(font, s2d);
		text.text = "Hello MCP!";
		text.name = "TestTextNode";

		Thread.create(runTestClient);
	}

	function runTestClient() {
		Sys.sleep(1.0);

		trace("=== Testing HeapsProtocolServer agent transport ===");

		trace("Running GET_SCENE test...");
		var socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		socket.write("GET_SCENE\n");
		var sceneRes = socket.read();
		socket.close();

		var sceneJson: Dynamic = Json.parse(sceneRes);
		var foundText = false;
		var foundId = false;
		function findText(node: Dynamic) {
			if (node.name == "TestTextNode" && node.text == "Hello MCP!") {
				foundText = true;
				if (node.id != null)
					foundId = true;
			}
			if (node.children != null) {
				var arr: Array<Dynamic> = node.children;
				for (child in arr)
					findText(child);
			}
		}
		findText(sceneJson);

		if (foundText && foundId) {
			trace("GET_SCENE: SUCCESS");
		} else {
			trace("GET_SCENE: FAILED - text=" + foundText + " id=" + foundId);
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
			trace("GET_SCREENSHOT: FAILED");
		}

		trace("Running EXECUTE_HSCRIPT success test...");
		socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		var testCode = "s2d.numChildren";
		socket.write("EXECUTE_HSCRIPT:" + Base64.encode(Bytes.ofString(testCode)) + "\n");
		var hscriptRes = socket.read();
		socket.close();
		var hscriptJson: Dynamic = Json.parse(hscriptRes);
		if (hscriptJson != null && hscriptJson.success == true && hscriptJson.result != null) {
			trace("EXECUTE_HSCRIPT: SUCCESS");
		} else {
			trace("EXECUTE_HSCRIPT: FAILED - " + hscriptRes);
		}

		trace("Running EXECUTE_HSCRIPT error recovery test...");
		socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		socket.write("EXECUTE_HSCRIPT:" + Base64.encode(Bytes.ofString("get2d_missing_should_throw")) + "\n");
		var errRes = socket.read();
		socket.close();
		var errJson: Dynamic = Json.parse(errRes);
		if (errJson != null && errJson.success == false && errJson.error != null) {
			trace("EXECUTE_HSCRIPT error: SUCCESS");
		} else {
			trace("EXECUTE_HSCRIPT error: FAILED - " + errRes);
		}

		trace("Running GET_SCENE after hscript error (hang regression)...");
		socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		socket.write("GET_SCENE\n");
		var afterErr = socket.read();
		socket.close();
		if (afterErr != null && afterErr.length > 10) {
			trace("POST-ERROR GET_SCENE: SUCCESS");
		} else {
			trace("POST-ERROR GET_SCENE: FAILED (server hung?)");
		}

		trace("Running FIND_NODES test...");
		socket = new Socket();
		socket.connect(new Host("127.0.0.1"), 8080);
		var findPayload = Json.stringify({ textContains: "Hello MCP" });
		socket.write("FIND_NODES:" + Base64.encode(Bytes.ofString(findPayload)) + "\n");
		var findRes = socket.read();
		socket.close();
		var findJson: Dynamic = Json.parse(findRes);
		if (findJson != null && findJson.success == true && findJson.count > 0) {
			trace("FIND_NODES: SUCCESS");
		} else {
			trace("FIND_NODES: FAILED - " + findRes);
		}

		trace("Running get2d binding test...");
		var snap: Dynamic = Json.parse(afterErr);
		var textId: String = null;
		function findId(node: Dynamic) {
			if (node.name == "TestTextNode")
				textId = node.id;
			if (node.children != null) {
				for (child in (node.children : Array<Dynamic>))
					findId(child);
			}
		}
		findId(snap);
		if (textId != null) {
			socket = new Socket();
			socket.connect(new Host("127.0.0.1"), 8080);
			var code = "var o = get2d(\"" + textId + "\"); o.text";
			socket.write("EXECUTE_HSCRIPT:" + Base64.encode(Bytes.ofString(code)) + "\n");
			var get2dRes = socket.read();
			socket.close();
			var get2dJson: Dynamic = Json.parse(get2dRes);
			if (get2dJson != null && get2dJson.success == true && get2dJson.result == "Hello MCP!") {
				trace("get2d binding: SUCCESS");
			} else {
				trace("get2d binding: FAILED - " + get2dRes);
			}
		} else {
			trace("get2d binding: SKIPPED - no id");
		}

		trace("=== Testing McpMain JSON-RPC ===");

		var pipeServer = new Socket();
		pipeServer.bind(new Host("127.0.0.1"), 8081);
		pipeServer.listen(1);

		var mcpClientPipe = new Socket();
		mcpClientPipe.connect(new Host("127.0.0.1"), 8081);
		var mcpServerPipe = pipeServer.accept();
		pipeServer.close();

		Thread.create(function() {
			cgd.cli.mcp.McpMain.run(Sys.getCwd(), Sys.getCwd(), mcpServerPipe.input, mcpServerPipe.output);
		});

		trace("Running MCP initialize test...");
		mcpClientPipe.output.writeString(Json.stringify({
			jsonrpc: "2.0", id: 1, method: "initialize", params: {}
		}) + "\n");
		var initRes: Dynamic = Json.parse(mcpClientPipe.input.readLine());
		if (initRes.result != null && initRes.result.serverInfo != null && initRes.result.serverInfo.name == "cgdheaps-mcp") {
			trace("MCP initialize: SUCCESS");
		} else {
			trace("MCP initialize: FAILED");
		}

		trace("Running MCP tools/list test...");
		mcpClientPipe.output.writeString(Json.stringify({
			jsonrpc: "2.0", id: 2, method: "tools/list", params: {}
		}) + "\n");
		var listRes: Dynamic = Json.parse(mcpClientPipe.input.readLine());
		if (listRes.result != null && listRes.result.tools != null && listRes.result.tools.length >= 8) {
			trace("MCP tools/list: SUCCESS");
		} else {
			trace("MCP tools/list: FAILED");
		}

		trace("Running MCP tools/call get_scene_tree test...");
		mcpClientPipe.output.writeString(Json.stringify({
			jsonrpc: "2.0", id: 3, method: "tools/call",
			params: { name: "get_scene_tree", arguments: {} }
		}) + "\n");
		var callRes: Dynamic = Json.parse(mcpClientPipe.input.readLine());
		if (callRes.result != null && callRes.result.content != null && callRes.result.content[0].type == "text") {
			trace("MCP tools/call get_scene_tree: SUCCESS");
		} else {
			trace("MCP tools/call get_scene_tree: FAILED");
		}

		trace("Running MCP tools/call execute_hscript test...");
		mcpClientPipe.output.writeString(Json.stringify({
			jsonrpc: "2.0", id: 4, method: "tools/call",
			params: { name: "execute_hscript", arguments: { code: "s2d.numChildren" } }
		}) + "\n");
		var callScriptRes: Dynamic = Json.parse(mcpClientPipe.input.readLine());
		if (callScriptRes.result != null && callScriptRes.result.content != null) {
			var innerJson: Dynamic = Json.parse(callScriptRes.result.content[0].text);
			if (innerJson.success == true && innerJson.result != null) {
				trace("MCP tools/call execute_hscript: SUCCESS");
			} else {
				trace("MCP tools/call execute_hscript: FAILED (inner result)");
			}
		} else {
			trace("MCP tools/call execute_hscript: FAILED");
		}

		Sys.exit(0);
	}
}
