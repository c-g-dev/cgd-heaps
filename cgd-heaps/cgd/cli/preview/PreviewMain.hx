package cgd.cli.preview;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class PreviewMain {

    static inline var PREVIEW_ROOT:String = ".cgdheaps";
    static inline var PREVIEW_DIR:String = "preview";
    static inline var OUTPUT_FILE:String = "preview.hl";

    public static function run(moduleName:String, callerCwd:String, libraryRoot:String):Void {
        var cleanModule = StringTools.trim(moduleName);
        if( cleanModule == "" ) {
            throw "Preview module name cannot be empty.";
        }

        var workingDirectory = normalizeDirectory(callerCwd);
        var libDirectory = normalizeDirectory(libraryRoot);
        Sys.setCwd(workingDirectory);

        var selectedHxml = selectHxml();
        var dependencyArgs = extractDependencyArgs(selectedHxml);
        var tempDirectory = resolveTempDirectory();
        ensurePreviewDirectory(tempDirectory);
        var outputFile = resolveOutputFile(tempDirectory);

        var compileArgs = dependencyArgs.copy();
        compileArgs.push("-cp");
        compileArgs.push(libDirectory);
        compileArgs.push("-main");
        compileArgs.push("cgd.cli.preview.PreviewApp");
        compileArgs.push("-D");
        compileArgs.push('cgd_preview_module=${cleanModule}');
        compileArgs.push("-hl");
        compileArgs.push(outputFile);

        Sys.println('Compiling preview from ${selectedHxml}...');
        var compileExitCode = Sys.command("haxe", compileArgs);
        if( compileExitCode != 0 ) {
            throw "Preview compile failed.";
        }

        Sys.println('Launching preview for ${cleanModule}...');
        var runExitCode = Sys.command("hl", [outputFile]);
        if( runExitCode != 0 ) {
            throw "Preview runtime exited with errors.";
        }
    }

    static function selectHxml():String {
        var hxmlFiles = [];
        for( entry in FileSystem.readDirectory(".") ) {
            trace(entry);
            if( !StringTools.endsWith(entry, ".hxml") ) {
                continue;
            }
            if( FileSystem.isDirectory(entry) ) {
                continue;
            }
            hxmlFiles.push(entry);
        }

        if( hxmlFiles.length == 0 ) {
            throw "No .hxml file found in the current working directory.";
        }

        hxmlFiles.sort(function(a, b) return Reflect.compare(a, b));
        for( file in hxmlFiles ) {
            if( file == "build.hxml" ) {
                return file;
            }
        }

        if( hxmlFiles.length == 1 ) {
            return hxmlFiles[0];
        }

        throw 'Multiple .hxml files found. Add build.hxml or leave only one: ${hxmlFiles.join(", ")}';
    }

    static function extractDependencyArgs(hxmlPath:String):Array<String> {
        var args:Array<String> = [];
        var pendingOption:Null<String> = null;
        var pendingOptionIsKept = false;

        var content = File.getContent(hxmlPath);
        var lines = content.split("\n");
        for( line in lines ) {
            var tokens = tokenizeHxmlLine(line);
            var index = 0;
            while( index < tokens.length ) {
                var token = tokens[index];

                if( pendingOption != null ) {
                    if( pendingOptionIsKept ) {
                        args.push(pendingOption);
                        args.push(token);
                    }
                    pendingOption = null;
                    pendingOptionIsKept = false;
                    index++;
                    continue;
                }

                if( token == "--next" ) {
                    return args;
                }

                if( appendInlineDependencyToken(token, args) ) {
                    index++;
                    continue;
                }

                if( optionExpectsValue(token) ) {
                    if( index + 1 < tokens.length ) {
                        var value = tokens[index + 1];
                        if( isDependencyOption(token) ) {
                            args.push(token);
                            args.push(value);
                        }
                        index += 2;
                        continue;
                    }
                    pendingOption = token;
                    pendingOptionIsKept = isDependencyOption(token);
                    index++;
                    continue;
                }

                index++;
            }
        }

        if( pendingOption != null ) {
            throw 'hxml option ${pendingOption} is missing a value in ${hxmlPath}.';
        }
        return args;
    }

    static function optionExpectsValue(option:String):Bool {
        return switch( option ) {
            case "-cp", "-p", "--class-path", "-lib", "-D", "--macro", "--remap":
                true;
            default:
                false;
        };
    }

    static function isDependencyOption(option:String):Bool {
        return switch( option ) {
            case "-cp", "-p", "--class-path", "-lib", "-D", "--macro", "--remap":
                true;
            default:
                false;
        };
    }

    static function appendInlineDependencyToken(token:String, out:Array<String>):Bool {
        if( StringTools.startsWith(token, "-D") && token.length > 2 ) {
            out.push(token);
            return true;
        }
        if( StringTools.startsWith(token, "-lib") && token.length > 4 ) {
            out.push("-lib");
            out.push(token.substr(4));
            return true;
        }
        if( StringTools.startsWith(token, "-cp") && token.length > 3 ) {
            out.push("-cp");
            out.push(token.substr(3));
            return true;
        }
        if( StringTools.startsWith(token, "-p") && token.length > 2 ) {
            out.push("-p");
            out.push(token.substr(2));
            return true;
        }
        if( StringTools.startsWith(token, "--class-path=") ) {
            out.push("--class-path");
            out.push(token.substr("--class-path=".length));
            return true;
        }
        if( StringTools.startsWith(token, "--macro=") ) {
            out.push("--macro");
            out.push(token.substr("--macro=".length));
            return true;
        }
        if( StringTools.startsWith(token, "--remap=") ) {
            out.push("--remap");
            out.push(token.substr("--remap=".length));
            return true;
        }
        return false;
    }

    static function tokenizeHxmlLine(line:String):Array<String> {
        var tokens:Array<String> = [];
        var current = "";
        var quoteCode = 0;
        var escapeNext = false;
        var index = 0;
        while( index < line.length ) {
            var code = line.charCodeAt(index);

            if( escapeNext ) {
                current += String.fromCharCode(code);
                escapeNext = false;
                index++;
                continue;
            }

            if( quoteCode != 0 && code == 92 ) { // \
                escapeNext = true;
                index++;
                continue;
            }

            if( quoteCode == 0 && code == 35 ) { // #
                break;
            }

            if( quoteCode == 0 && (code == 34 || code == 39) ) { // " or '
                quoteCode = code;
                index++;
                continue;
            }

            if( quoteCode != 0 && code == quoteCode ) {
                quoteCode = 0;
                index++;
                continue;
            }

            if( quoteCode == 0 && isWhitespace(code) ) {
                if( current != "" ) {
                    tokens.push(current);
                    current = "";
                }
                index++;
                continue;
            }

            current += String.fromCharCode(code);
            index++;
        }

        if( current != "" ) {
            tokens.push(current);
        }
        return tokens;
    }

    static function isWhitespace(code:Int):Bool {
        return code == 32 || code == 9 || code == 13 || code == 10;
    }

    static function resolveOutputFile(tempDirectory:String):String {
        return appendPath(resolvePreviewDirectory(tempDirectory), OUTPUT_FILE);
    }

    static function resolvePreviewDirectory(tempDirectory:String):String {
        return appendPath(
            appendPath(tempDirectory, PREVIEW_ROOT),
            PREVIEW_DIR
        );
    }

    static function ensurePreviewDirectory(tempDirectory:String):Void {
        var previewRoot = appendPath(tempDirectory, PREVIEW_ROOT);
        if( !FileSystem.exists(previewRoot) ) {
            FileSystem.createDirectory(previewRoot);
        }
        if( !FileSystem.exists(previewRoot) || !FileSystem.isDirectory(previewRoot) ) {
            throw 'Could not prepare temporary preview directory: ${previewRoot}';
        }

        var previewDirectory = appendPath(previewRoot, PREVIEW_DIR);
        if( !FileSystem.exists(previewDirectory) ) {
            FileSystem.createDirectory(previewDirectory);
        }
        if( !FileSystem.exists(previewDirectory) || !FileSystem.isDirectory(previewDirectory) ) {
            throw 'Could not prepare temporary preview directory: ${previewDirectory}';
        }
    }

    static function resolveTempDirectory():String {
        var tempDirectory = directoryFromEnv("TMPDIR");
        if( tempDirectory != null ) {
            return tempDirectory;
        }

        tempDirectory = directoryFromEnv("TEMP");
        if( tempDirectory != null ) {
            return tempDirectory;
        }

        tempDirectory = directoryFromEnv("TMP");
        if( tempDirectory != null ) {
            return tempDirectory;
        }

        var localAppData = directoryFromEnv("LOCALAPPDATA");
        if( localAppData != null ) {
            var tempFromLocalAppData = appendPath(localAppData, "Temp");
            if( !FileSystem.exists(tempFromLocalAppData) ) {
                FileSystem.createDirectory(tempFromLocalAppData);
            }
            if( FileSystem.exists(tempFromLocalAppData) && FileSystem.isDirectory(tempFromLocalAppData) ) {
                return tempFromLocalAppData;
            }
        }

        var userProfile = directoryFromEnv("USERPROFILE");
        if( userProfile != null ) {
            var tempFromProfile = appendPath(appendPath(userProfile, "AppData"), "Local/Temp");
            if( !FileSystem.exists(tempFromProfile) ) {
                FileSystem.createDirectory(tempFromProfile);
            }
            if( FileSystem.exists(tempFromProfile) && FileSystem.isDirectory(tempFromProfile) ) {
                return tempFromProfile;
            }
        }

        if( FileSystem.exists("/tmp") && FileSystem.isDirectory("/tmp") ) {
            return normalizePath("/tmp");
        }

        throw "Could not resolve a temporary directory for preview compilation.";
    }

    static function directoryFromEnv(environmentVariable:String):Null<String> {
        var value = Sys.getEnv(environmentVariable);
        if( value == null || value == "" ) {
            return null;
        }
        var normalized = normalizePath(value);
        if( !FileSystem.exists(normalized) || !FileSystem.isDirectory(normalized) ) {
            return null;
        }
        return normalized;
    }

    static function appendPath(base:String, child:String):String {
        var normalizedBase = normalizePath(base);
        var normalizedChild = normalizePath(child);
        if( normalizedBase == "" ) {
            return normalizedChild;
        }
        if( normalizedChild == "" ) {
            return normalizedBase;
        }
        if( StringTools.endsWith(normalizedBase, "/") ) {
            return normalizedBase + normalizedChild;
        }
        return normalizedBase + "/" + normalizedChild;
    }

    static function normalizeDirectory(path:String):String {
        var fullPath = path;
        if( !Path.isAbsolute(fullPath) ) {
            fullPath = FileSystem.fullPath(fullPath);
        }
        fullPath = fullPath.split("\\").join("/");
        while( fullPath.length > 1 && StringTools.endsWith(fullPath, "/") ) {
            fullPath = fullPath.substr(0, fullPath.length - 1);
        }

        if( !FileSystem.exists(fullPath) || !FileSystem.isDirectory(fullPath) ) {
            throw 'Directory does not exist: ${path}';
        }
        return fullPath;
    }

    static function normalizePath(path:String):String {
        var normalized = path.split("\\").join("/");
        while( normalized.indexOf("//") >= 0 ) {
            normalized = normalized.split("//").join("/");
        }
        if( normalized.length > 1 && StringTools.endsWith(normalized, "/") ) {
            normalized = normalized.substr(0, normalized.length - 1);
        }
        return normalized;
    }

}
