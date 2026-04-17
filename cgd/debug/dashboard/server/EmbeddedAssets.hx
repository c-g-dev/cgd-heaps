package cgd.debug.dashboard.server;

class EmbeddedAssets {
	public static var dashboardHtml(default, null):String = hxd.res.Embed.getFileContent("cgd/debug/dashboard/ui/bin/dashboard.html");
	public static var uiJs(default, null):String = hxd.res.Embed.getFileContent("cgd/debug/dashboard/ui/bin/ui.js");
}
