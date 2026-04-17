package cgd.debug.dashboard.server.endpoints;

import cgd.debug.dashboard.HeapsDebugServer;
import cgd.debug.dashboard.server.EmbeddedAssets;
import cgd.debug.dashboard.HeapsDebugServer.IHeapsDebugEndpoint;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugRequest;
import cgd.debug.dashboard.HeapsDebugServer.HeapsDebugResponse;

class Dashboard implements IHeapsDebugEndpoint {
	public var method(default, null): String = "GET";
	public var path(default, null): String;

	public static function register(): Void {
		HeapsDebugServer.registerEndpoint(new Dashboard("/dashboard"));
		HeapsDebugServer.registerEndpoint(new Dashboard("/"));
	}

	public function new(path: String = "/dashboard") {
		this.path = path;
	}

	public function handle(server: HeapsDebugServer, req: HeapsDebugRequest): HeapsDebugResponse {
		var html = EmbeddedAssets.dashboardHtml;
		
		var tabHeaders = new StringBuf();
		var tabContents = new StringBuf();

		@:privateAccess for (tab in HeapsDebugServer.tabs) {
			tabHeaders.add('<button class="tab-btn" data-target="${tab.id}">${tab.label}</button>\n');
			tabContents.add('<div id="${tab.id}" class="tab-pane" style="display:none;">${tab.htmlContent}</div>\n');
		}

		html = StringTools.replace(html, "<!-- INJECT_TAB_HEADERS -->", tabHeaders.toString());
		html = StringTools.replace(html, "<!-- INJECT_TAB_CONTENTS -->", tabContents.toString());

		if (html.indexOf("/ui.js") == -1) {
			var marker = "</body>";
			var idx = html.indexOf(marker);
			if (idx >= 0) {
				html = html.substr(0, idx)
					+ "\n<script src=\"/ui.js\"></script>\n"
					+ html.substr(idx);
			}
		}
		return {
			status: 200,
			contentType: "text/html; charset=utf-8",
			body: html
		};
	}
}

