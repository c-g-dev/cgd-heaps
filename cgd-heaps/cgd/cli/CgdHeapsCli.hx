package cgd.cli;

import haxe.io.Path;
import sys.FileSystem;

private typedef RunInvocation = {
    var args:Array<String>;
    var callerCwd:String;
    var libraryRoot:String;
}

class CgdHeapsCli {

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
        
        // We expect the script wrappers (cgdheaps.cmd or cgdheaps shell script) to pass the 
        // original working directory as the last argument, and the library root as the second to last argument.
        // Wait, actually, let's just use environment variables to make it cleaner.
        // CGDHEAPS_CWD : The caller's CWD
        // CGDHEAPS_LIB_ROOT : The root of the cgd-heaps library
        
        var callerCwd = Sys.getEnv("CGDHEAPS_CWD");
        if (callerCwd == null) {
            callerCwd = Sys.getCwd();
        }
        
        var libraryRoot = Sys.getEnv("CGDHEAPS_LIB_ROOT");
        if (libraryRoot == null) {
            // fallback to finding the library root relative to this executable if possible
            var exePath = Sys.programPath();
            if (exePath != null) {
                libraryRoot = Path.directory(exePath);
            } else {
                libraryRoot = Sys.getCwd();
            }
        }
        
        return {
            args: args,
            callerCwd: normalizeDirectory(callerCwd),
            libraryRoot: normalizeDirectory(libraryRoot)
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
    }

}
