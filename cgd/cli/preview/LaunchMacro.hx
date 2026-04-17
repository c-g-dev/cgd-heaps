package cgd.cli.preview;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

private typedef ModuleMatch = {
    var module:String;
    var filePath:String;
}
#end

class LaunchMacro {

    public static macro function launch(app:haxe.macro.Expr.Expr) {
        return buildLaunchExpr(app);
    }

    #if macro
    static inline var MODULE_DEFINE = "cgd_preview_module";

    static function buildLaunchExpr(app:Expr):Expr {
        var moduleNameValue = Context.definedValue(MODULE_DEFINE);
        if( moduleNameValue == null ) {
            return macro throw $v{'Missing -D ${MODULE_DEFINE}=<module> define.'};
        }

        var requestedModule = StringTools.trim(moduleNameValue);
        if( requestedModule == "" ) {
            return macro throw $v{'Define ${MODULE_DEFINE} cannot be empty.'};
        }

        var resolved = resolveModule(requestedModule);
        var className = resolved.module.split(".").pop();
        var requiredConstructorArgCount = countRequiredConstructorArgs(resolved.filePath, className);

        var constructorArgs:Array<Expr> = [];
        for( i in 0...requiredConstructorArgCount ) {
            constructorArgs.push(macro null);
        }
        var resolvedModuleName = resolved.module;
        var classPath = resolvedModuleName.split(".");
        return macro {
            var previewClass:Class<Dynamic> = cast $p{classPath};

            var launchHook = Reflect.field(previewClass, "__launch__");
            if( launchHook != null ) {
                Reflect.callMethod(previewClass, launchHook, [$app]);
            } else {
                var previewObject:h2d.Object = cast Type.createInstance(previewClass, $a{constructorArgs});
                if( previewObject.parent == null ) {
                    $app.s2d.addChild(previewObject);
                }
            }
        };
    }

    static function resolveModule(requested:String):ModuleMatch {
        var available = discoverModules();
        if( requested.indexOf(".") >= 0 ) {
            for( module in available ) {
                if( module.module == requested ) {
                    return module;
                }
            }
            Context.error('Could not find module "${requested}" in current classpaths.', Context.currentPos());
            return {
                module: "",
                filePath: ""
            };
        }

        var suffix = "." + requested;
        var candidates:Array<ModuleMatch> = [];
        for( module in available ) {
            if( module.module == requested || StringTools.endsWith(module.module, suffix) ) {
                candidates.push(module);
            }
        }

        candidates.sort(function(a, b) return Reflect.compare(a.module, b.module));
        if( candidates.length == 0 ) {
            Context.error('Could not find module "${requested}" in current classpaths.', Context.currentPos());
            return {
                module: "",
                filePath: ""
            };
        }
        if( candidates.length > 1 ) {
            var names = [for( candidate in candidates ) candidate.module];
            Context.error(
                'Module name "${requested}" is ambiguous. Use a fully qualified module.\nCandidates: '
                + names.join(", "),
                Context.currentPos()
            );
            return {
                module: "",
                filePath: ""
            };
        }
        return candidates[0];
    }

    static function countRequiredConstructorArgs(filePath:String, className:String):Int {
        var content = sys.io.File.getContent(filePath);
        var classStart = content.indexOf("class " + className);
        if( classStart < 0 ) {
            return 0;
        }

        var newIndex = content.indexOf("function new(", classStart);
        if( newIndex < 0 ) {
            return 0;
        }

        var openParen = content.indexOf("(", newIndex);
        if( openParen < 0 ) {
            return 0;
        }

        var closeParen = findMatchingParen(content, openParen);
        if( closeParen < 0 ) {
            return 0;
        }

        var paramsContent = content.substr(openParen + 1, closeParen - openParen - 1);
        var params = splitTopLevel(paramsContent, ",");
        var requiredCount = 0;
        for( param in params ) {
            var trimmed = StringTools.trim(param);
            if( trimmed == "" ) {
                continue;
            }

            var optional = StringTools.startsWith(trimmed, "?") || trimmed.indexOf("=") >= 0;
            if( !optional ) {
                requiredCount++;
            }
        }
        return requiredCount;
    }

    static function findMatchingParen(source:String, openParenIndex:Int):Int {
        var depth = 0;
        var quoteCode = 0;
        var escapeNext = false;
        var index = openParenIndex;
        while( index < source.length ) {
            var code = source.charCodeAt(index);

            if( escapeNext ) {
                escapeNext = false;
                index++;
                continue;
            }

            if( quoteCode != 0 && code == 92 ) { // \
                escapeNext = true;
                index++;
                continue;
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
            if( quoteCode != 0 ) {
                index++;
                continue;
            }

            if( code == 40 ) { // (
                depth++;
            } else if( code == 41 ) { // )
                depth--;
                if( depth == 0 ) {
                    return index;
                }
            }
            index++;
        }
        return -1;
    }

    static function splitTopLevel(source:String, delimiter:String):Array<String> {
        var parts:Array<String> = [];
        var current = "";
        var quoteCode = 0;
        var escapeNext = false;
        var parenDepth = 0;
        var bracketDepth = 0;
        var braceDepth = 0;
        var angleDepth = 0;

        var delimiterCode = delimiter.charCodeAt(0);
        var index = 0;
        while( index < source.length ) {
            var code = source.charCodeAt(index);

            if( escapeNext ) {
                current += String.fromCharCode(code);
                escapeNext = false;
                index++;
                continue;
            }

            if( quoteCode != 0 && code == 92 ) { // \
                current += String.fromCharCode(code);
                escapeNext = true;
                index++;
                continue;
            }

            if( quoteCode == 0 && (code == 34 || code == 39) ) { // " or '
                quoteCode = code;
                current += String.fromCharCode(code);
                index++;
                continue;
            }
            if( quoteCode != 0 && code == quoteCode ) {
                quoteCode = 0;
                current += String.fromCharCode(code);
                index++;
                continue;
            }
            if( quoteCode != 0 ) {
                current += String.fromCharCode(code);
                index++;
                continue;
            }

            switch( code ) {
                case 40: parenDepth++; // (
                case 41: if( parenDepth > 0 ) parenDepth--; // )
                case 91: bracketDepth++; // [
                case 93: if( bracketDepth > 0 ) bracketDepth--; // ]
                case 123: braceDepth++; // {
                case 125: if( braceDepth > 0 ) braceDepth--; // }
                case 60: angleDepth++; // <
                case 62: if( angleDepth > 0 ) angleDepth--; // >
                default:
            }

            if(
                code == delimiterCode
                && parenDepth == 0
                && bracketDepth == 0
                && braceDepth == 0
                && angleDepth == 0
            ) {
                parts.push(current);
                current = "";
                index++;
                continue;
            }

            current += String.fromCharCode(code);
            index++;
        }

        parts.push(current);
        return parts;
    }

    static var discoveredModulesCache:Null<Array<ModuleMatch>> = null;

    static function discoverModules():Array<ModuleMatch> {
        if( discoveredModulesCache != null ) {
            return discoveredModulesCache.copy();
        }

        var discovered = new Map<String, ModuleMatch>();
        var stdRoot = normalizePath(parentDir(Context.resolvePath("StdTypes.hx"))).toLowerCase();

        for( classPath in Context.getClassPath() ) {
            var absolutePath = ensureAbsolute(classPath);
            if( absolutePath == null || absolutePath == "" ) {
                continue;
            }

            var normalizedLower = absolutePath.toLowerCase();
            if( normalizedLower == stdRoot || StringTools.startsWith(normalizedLower, stdRoot + "/") ) {
                continue;
            }
            if( !sys.FileSystem.exists(absolutePath) || !sys.FileSystem.isDirectory(absolutePath) ) {
                continue;
            }

            scanModulesRec(absolutePath, absolutePath, discovered);
        }

        var modules = [for( moduleName in discovered.keys() ) discovered.get(moduleName)];
        modules.sort(function(a, b) return Reflect.compare(a.module, b.module));
        discoveredModulesCache = modules;
        return modules.copy();
    }

    static function scanModulesRec(rootPath:String, currentPath:String, discovered:Map<String, ModuleMatch>):Void {
        for( entry in sys.FileSystem.readDirectory(currentPath) ) {
            if( entry == ".git" || entry == ".svn" || entry == ".hg" ) {
                continue;
            }

            var fullPath = normalizePath(currentPath + "/" + entry);
            if( sys.FileSystem.isDirectory(fullPath) ) {
                if( StringTools.startsWith(entry, ".") ) {
                    continue;
                }
                scanModulesRec(rootPath, fullPath, discovered);
                continue;
            }

            if( !StringTools.endsWith(entry, ".hx") ) {
                continue;
            }

            var relativePath = fullPath.substr(rootPath.length + 1);
            var moduleName = relativePath.substr(0, relativePath.length - 3).split("/").join(".");
            if( isValidModuleName(moduleName) ) {
                discovered.set(moduleName, {
                    module: moduleName,
                    filePath: fullPath
                });
            }
        }
    }

    static function isValidModuleName(moduleName:String):Bool {
        if( moduleName == null || moduleName == "" ) {
            return false;
        }

        for( part in moduleName.split(".") ) {
            if( !~/^[A-Za-z_][A-Za-z0-9_]*$/.match(part) ) {
                return false;
            }
            if( StringTools.startsWith(part, "_") ) {
                return false;
            }
        }
        return true;
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

    static function ensureAbsolute(path:String):String {
        if( path == null || path == "" ) {
            return path;
        }
        if( haxe.io.Path.isAbsolute(path) ) {
            return normalizePath(path);
        }
        return normalizePath(sys.FileSystem.fullPath(path));
    }

    static function parentDir(path:String):String {
        var normalized = normalizePath(path);
        var index = normalized.lastIndexOf("/");
        if( index < 0 ) {
            return normalized;
        }
        if( index == 0 ) {
            return normalized;
        }
        if( index == 2 && normalized.charAt(1) == ":" ) {
            return normalized.substr(0, 3);
        }
        return normalized.substr(0, index);
    }
    #end

}
