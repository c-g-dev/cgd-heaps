import haxe.io.Path;
import sys.FileSystem;

private typedef RunInvocation = {
    var args:Array<String>;
    var callerCwd:String;
    var libraryRoot:String;
}

class Run {

    static function main():Void {
        var invocation = parseInvocation(Sys.args());
        if( invocation.args.length == 0 ) {
            printUsage();
            return;
        }

        var command = invocation.args[0];
        switch( command ) {
            case "preview":
                if( invocation.args.length < 2 ) {
                    throw "Usage: cgdheaps preview <module>";
                }
                cgd.cli.preview.PreviewMain.run(invocation.args[1], invocation.callerCwd, invocation.libraryRoot);
            case "mcp":
                cgd.cli.mcp.McpMain.run(invocation.callerCwd, invocation.libraryRoot);
            default:
                throw 'Unknown cgdheaps command "${command}". Supported commands: preview, mcp';
        }
    }

    static function parseInvocation(rawArgs:Array<String>):RunInvocation {
        var args = rawArgs.copy();
        var libraryRoot = normalizeDirectory(Sys.getCwd());

        var callerCwd = libraryRoot;
        if( Sys.getEnv("CGDHEAPS_RUN") == "1" && args.length > 0 ) {
            callerCwd = normalizeDirectory(args.pop());
        }

        return {
            args: args,
            callerCwd: callerCwd,
            libraryRoot: libraryRoot
        };
    }

    static function normalizeDirectory(path:String):String {
        var full = path;
        if( !Path.isAbsolute(full) ) {
            full = FileSystem.fullPath(full);
        }

        full = full.split("\\").join("/");
        while( full.length > 1 && StringTools.endsWith(full, "/") ) {
            full = full.substr(0, full.length - 1);
        }

        if( !FileSystem.exists(full) || !FileSystem.isDirectory(full) ) {
            throw 'Directory does not exist: ${path}';
        }
        return full;
    }

    static function printUsage():Void {
        Sys.println("cgdheaps command line tools");
        Sys.println("");
        Sys.println("Usage:");
        Sys.println("  cgdheaps preview <module>");
        Sys.println("  cgdheaps mcp");
        Sys.println("  haxe --run Run.hx preview <module>");
        Sys.println("  haxe --run Run.hx mcp");
    }

}
