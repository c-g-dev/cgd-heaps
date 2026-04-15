package hxd.res;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;

private typedef ScopeInfo = {
	var id : String;
	var key : String;
	var paths : Array<String>;
	var rootKeys : Array<String>;
	var typePath : TypePath;
}

private typedef RootInfo = {
	var key : String;
	var path : String;
}

private typedef ResourcePathMetadata = {
	var kind : String;
	var value : Null<String>;
	var pos : Position;
}
#end

class ScopedRes {

	#if macro
	static var setupDone = false;
	static var classpathScanned = false;
	static var discoveredModules : Array<String>;
	static var defaultPaths : Array<String>;
	static var defaultScope : ScopeInfo;
	static var scopeByKey : Map<String,ScopeInfo> = new Map();
	static var scopeByFile : Map<String,ScopeInfo> = new Map();
	static var scopeByClass : Map<String,ScopeInfo> = new Map();
	static var scopeById : Map<String,ScopeInfo> = new Map();
	static var rootKeyByPath : Map<String,String> = new Map();
	static var rootPathByKey : Map<String,String> = new Map();
	static var scopeTypeDefined : Map<String,Bool> = new Map();
	static var rewriteIgnoreFields = [for( f in ["initEmbed","initLocal","initPak","load","loader"] ) f => true];

	static function setup() {
		if( setupDone )
			return;
		setupDone = true;
		var targets = discoverMetadataModules();
		for( mod in targets ) {
			//trace("Adding global metadata for " + mod);
			Compiler.addGlobalMetadata(mod, "@:build(hxd.res.ScopedRes.rewriteType())", false, true, false);
		}
	}

	static function isValidIdent( s : String ) {
		if( s == null || s == "" )
			return false;
		return ~/^[A-Za-z_][A-Za-z0-9_]*$/.match(s);
	}

	static function discoverMetadataModules() {
		if( discoveredModules != null )
			return discoveredModules.copy();
		var moduleMap = new Map<String,Bool>();
		var stdRoot = normalizePath(parentDir(Context.resolvePath("StdTypes.hx"))).toLowerCase();
		for( cp in Context.getClassPath() ) {
			var abs = ensureAbsolute(cp);
			if( abs == null || abs == "" )
				continue;
			var normalized = normalizePath(abs);
			var normalizedLower = normalized.toLowerCase();
			if( normalizedLower == stdRoot || StringTools.startsWith(normalizedLower, stdRoot + "/") )
				continue;
			if( !sys.FileSystem.exists(normalized) || !sys.FileSystem.isDirectory(normalized) )
				continue;
			var stack = [normalized];
			while( stack.length > 0 ) {
				var dir = stack.pop();
				for( entry in sys.FileSystem.readDirectory(dir) ) {
					if( entry == ".git" || entry == ".svn" || entry == ".hg" )
						continue;
					var full = normalizePath(dir + "/" + entry);
					if( sys.FileSystem.isDirectory(full) ) {
						if( StringTools.startsWith(entry, ".") )
							continue;
						stack.push(full);
						continue;
					}
					if( !StringTools.endsWith(entry, ".hx") )
						continue;
					var rel = full.substr(normalized.length + 1);
					var module = rel.substr(0, rel.length - 3).split("/").join(".");
					var parts = module.split(".");
					var valid = true;
					for( part in parts ) {
						if( !isValidIdent(part) || StringTools.startsWith(part, "_") ) {
							valid = false;
							break;
						}
					}
					if( valid )
						moduleMap.set(module, true);
				}
			}
		}
		var modules = [for( k in moduleMap.keys() ) k];
		modules.sort(function( a, b ) return Reflect.compare(a, b));
		discoveredModules = modules;
		return discoveredModules.copy();
	}

	static function normalizePath( path : String ) {
		var p = path.split("\\").join("/");
		while( p.indexOf("//") >= 0 )
			p = p.split("//").join("/");
		if( p.length > 1 && StringTools.endsWith(p, "/") )
			p = p.substr(0, p.length - 1);
		return p;
	}

	static function ensureAbsolute( path : String ) {
		if( path == null || path == "" )
			return path;
		if( haxe.io.Path.isAbsolute(path) )
			return normalizePath(path);
		return normalizePath(sys.FileSystem.fullPath(path));
	}

	static function parentDir( path : String ) {
		var p = normalizePath(path);
		var idx = p.lastIndexOf("/");
		if( idx < 0 )
			return p;
		if( idx == 0 )
			return p;
		if( idx == 2 && p.charAt(1) == ":" )
			return p.substr(0, 3);
		return p.substr(0, idx);
	}

	static function isInternalHeapsResPath( path : String ) {
		var p = normalizePath(path);
		if( !StringTools.endsWith(p, "/hxd/res") )
			return false;
		// Ignore Heaps internal source folder if it gets discovered while scanning classpaths.
		return sys.FileSystem.exists(p + "/Loader.hx") && sys.FileSystem.exists(p + "/Resource.hx");
	}

	static function getDefaultPaths() {
		if( defaultPaths != null )
			return defaultPaths.copy();
		defaultPaths = [];
		for( p in FileTree.resolvePaths() ) {
			var n = normalizePath(p);
			if( sys.FileSystem.exists(n) && sys.FileSystem.isDirectory(n) && !isInternalHeapsResPath(n) )
				defaultPaths.push(n);
		}
		return defaultPaths.copy();
	}

	static function getResRootsForFile( file : String ) {
		var roots = [];
		var current = normalizePath(new haxe.io.Path(ensureAbsolute(file)).dir);
		while( true ) {
			var res = normalizePath(current + "/res");
			if( sys.FileSystem.exists(res) && sys.FileSystem.isDirectory(res) && !isInternalHeapsResPath(res) )
				roots.push(res);
			var parent = parentDir(current);
			if( parent == current )
				break;
			current = parent;
		}
		roots.reverse();
		return roots;
	}

	static function getScopePathsForFile( file : String ) {
		var roots = getResRootsForFile(file);
		if( roots.length == 0 )
			return getDefaultPaths();
		return roots;
	}

	static function getGlobalScopePathsForFile( file : String ) {
		var roots = getResRootsForFile(file);
		if( roots.length == 0 )
			return getDefaultPaths();
		return [roots[0]];
	}

	static function constStringArg( e : Expr, argName : String ) : Null<String> {
		if( e == null )
			return null;
		return switch( e.expr ) {
		case EConst(CString(s)):
			s;
		case EConst(CIdent("null")):
			null;
		default:
			Context.error(argName + " should be a string constant", e.pos);
			null;
		}
	}

	static function isMetadataNamed( name : String, expected : String ) {
		return name == expected || name == ":" + expected;
	}

	static function getClassPathString( cls : ClassType ) {
		var parts = cls.pack.copy();
		parts.push(cls.name);
		return parts.join(".");
	}

	static function getClassFile( cls : ClassType ) {
		var file = Context.getPosInfos(cls.pos).file;
		if( file == null || file == "" ) {
			Context.error("Could not determine source file for " + getClassPathString(cls), cls.pos);
			return null;
		}
		return ensureAbsolute(file);
	}

	static function getResourcePathMetadata( cls : ClassType ) : Null<ResourcePathMetadata> {
		var matches : Array<ResourcePathMetadata> = [];
		for( meta in cls.meta.get() ) {
			if( isMetadataNamed(meta.name, "resourcePath") ) {
				if( meta.params.length != 1 )
					Context.error("@resourcePath expects exactly one string argument", meta.pos);
				matches.push({
					kind : "resourcePath",
					value : constStringArg(meta.params[0], "@resourcePath"),
					pos : meta.pos,
				});
			}
			else if( isMetadataNamed(meta.name, "matchResourcePath") ) {
				if( meta.params.length != 1 )
					Context.error("@matchResourcePath expects exactly one string argument", meta.pos);
				matches.push({
					kind : "matchResourcePath",
					value : constStringArg(meta.params[0], "@matchResourcePath"),
					pos : meta.pos,
				});
			}
			else if( isMetadataNamed(meta.name, "globalResourcePath") ) {
				if( meta.params.length != 0 )
					Context.error("@globalResourcePath does not take any arguments", meta.pos);
				matches.push({
					kind : "globalResourcePath",
					value : null,
					pos : meta.pos,
				});
			}
		}
		if( matches.length > 1 )
			Context.error("Only one of @resourcePath, @matchResourcePath, or @globalResourcePath can be applied to " + getClassPathString(cls), cls.pos);
		return matches.length == 0 ? null : matches[0];
	}

	static function resolveMatchedClass( path : String, pos : Position ) : ClassType {
		var t = Context.follow(Context.getType(path));
		return switch( t ) {
		case TInst(c, _):
			c.get();
		default:
			Context.error("@matchResourcePath target must resolve to a class: " + path, pos);
			null;
		}
	}

	static function resolveResourcePath( baseFile : String, path : String, pos : Position ) {
		var resolved = path;
		if( !haxe.io.Path.isAbsolute(resolved) )
			resolved = normalizePath(parentDir(baseFile) + "/" + resolved);
		else
			resolved = normalizePath(resolved);
		if( !sys.FileSystem.exists(resolved) || !sys.FileSystem.isDirectory(resolved) )
			Context.error("Resolved resource path does not exist or is not a directory: " + resolved, pos);
		return resolved;
	}

	static function makeScopeKey( paths : Array<String> ) {
		return [for( p in paths ) normalizePath(p).toLowerCase()].join("|");
	}

	static function makeScopeId( key : String ) {
		var id = "s" + haxe.crypto.Md5.encode(key).substr(0, 12);
		var base = id;
		var idx = 1;
		while( scopeById.exists(id) && scopeById.get(id).key != key ) {
			id = base + "_" + idx++;
		}
		return id;
	}

	static function ensureRootKey( path : String ) {
		var p = normalizePath(path);
		var key = rootKeyByPath.get(p);
		if( key != null )
			return key;
		key = "r" + haxe.crypto.Md5.encode(p.toLowerCase()).substr(0, 12);
		var base = key;
		var idx = 1;
		while( rootPathByKey.exists(key) && rootPathByKey.get(key) != p ) {
			key = base + "_" + idx++;
		}
		rootKeyByPath.set(p, key);
		rootPathByKey.set(key, p);
		return key;
	}

	static function defineScopeType( scope : ScopeInfo ) {
		if( scopeTypeDefined.exists(scope.id) )
			return;
		var ft = new FileTree(null, scope.paths);
		ft.setTypeNamePrefix(scope.id + "_");
		var fields = ft.buildScopeFields(scope.id);
		var def = macro class {};
		Context.defineType({
			pack : scope.typePath.pack,
			name : scope.typePath.name,
			pos : Context.currentPos(),
			meta : [{ name : ":dce", params : [], pos : Context.currentPos() }],
			isExtern : false,
			fields : fields,
			params : [],
			kind : def.kind,
		});
		scopeTypeDefined.set(scope.id, true);
	}

	static function ensureScope( paths : Array<String>, defineType = true ) {
		var normalized = [for( p in paths ) normalizePath(p)];
		normalized = [for( p in normalized ) if( !isInternalHeapsResPath(p) ) p];
		if( normalized.length == 0 )
			normalized = getDefaultPaths();
		if( normalized.length == 0 )
			return null;
		var key = makeScopeKey(normalized);
		var existing = scopeByKey.get(key);
		if( existing != null ) {
			if( defineType )
				defineScopeType(existing);
			return existing;
		}
		var id = makeScopeId(key);
		var rootKeys = [for( p in normalized ) ensureRootKey(p)];
		var scope : ScopeInfo = {
			id : id,
			key : key,
			paths : normalized,
			rootKeys : rootKeys,
			typePath : {
				pack : ["hxd", "_res"],
				name : "Scope_" + id,
				params : []
			}
		};
		scopeByKey.set(key, scope);
		scopeById.set(id, scope);
		if( defineType )
			defineScopeType(scope);
		return scope;
	}

	static function ensureDefaultScope() {
		if( defaultScope == null ) {
			var paths = getDefaultPaths();
			if( paths.length > 0 )
				defaultScope = ensureScope(paths, true);
			else {
				var scopes = sortedScopes();
				if( scopes.length > 0 )
					defaultScope = scopes[0];
			}
		}
		if( defaultScope == null )
			throw "No resource scope was discovered. Add at least one res directory or set -D resourcesPath.";
		return defaultScope;
	}

	static function ensureScopeForFile( file : String, defineType = true ) {
		var path = ensureAbsolute(file);
		var s = scopeByFile.get(path);
		if( s != null ) {
			if( defineType )
				defineScopeType(s);
			return s;
		}
		s = ensureScope(getScopePathsForFile(path), defineType);
		if( s == null )
			return null;
		scopeByFile.set(path, s);
		return s;
	}

	static function ensureScopeForClassType( cls : ClassType, defineType = true, ?visiting : Map<String,Bool> ) {
		var classKey = getClassPathString(cls);
		var existing = scopeByClass.get(classKey);
		if( existing != null ) {
			if( defineType )
				defineScopeType(existing);
			return existing;
		}
		if( visiting == null )
			visiting = new Map();
		if( visiting.exists(classKey) )
			Context.error("Cyclic resource path metadata detected while resolving " + classKey, cls.pos);
		visiting.set(classKey, true);
		var file = getClassFile(cls);
		var meta = getResourcePathMetadata(cls);
		var scope = if( meta == null )
			ensureScopeForFile(file, defineType)
		else
			switch( meta.kind ) {
			case "resourcePath":
				ensureScope([resolveResourcePath(file, meta.value, meta.pos)], defineType);
			case "matchResourcePath":
				var matchedClass = resolveMatchedClass(meta.value, meta.pos);
				ensureScopeForClassType(matchedClass, defineType, visiting);
			case "globalResourcePath":
				ensureScope(getGlobalScopePathsForFile(file), defineType);
			default:
				Context.error("Unknown resource path metadata kind: " + meta.kind, meta.pos);
				null;
			}
		visiting.remove(classKey);
		if( scope != null )
			scopeByClass.set(classKey, scope);
		return scope;
	}

	static function collectRegexMatches( content : String, re : EReg, onMatch : String -> Void ) {
		var offset = 0;
		while( re.matchSub(content, offset) ) {
			onMatch(re.matched(1));
			var matched = re.matchedPos();
			offset = matched.pos + (matched.len > 0 ? matched.len : 1);
		}
	}

	static function collectMetadataScopesForFile( file : String ) {
		var content = sys.io.File.getContent(file);
		collectRegexMatches(content, ~/@:?resourcePath\s*\(\s*"([^"]+)"\s*\)/, function( path ) {
			ensureScope([resolveResourcePath(file, path, Context.currentPos())], true);
		});
		collectRegexMatches(content, ~/@:?matchResourcePath\s*\(\s*"([^"]+)"\s*\)/, function( path ) {
			var matchedClass = resolveMatchedClass(path, Context.currentPos());
			ensureScopeForClassType(matchedClass, true);
		});
		if( ~/@:?globalResourcePath\b/.match(content) )
			ensureScope(getGlobalScopePathsForFile(file), true);
	}

	static function scanClassPathRec( path : String, visited : Map<String,Bool> ) {
		var abs = normalizePath(path);
		if( visited.exists(abs) )
			return;
		visited.set(abs, true);
		for( f in sys.FileSystem.readDirectory(abs) ) {
			if( f == ".git" || f == ".svn" || f == "test" || f == "tests" )
				continue;
			var full = normalizePath(abs + "/" + f);
			if( sys.FileSystem.isDirectory(full) )
				scanClassPathRec(full, visited);
			else if( StringTools.endsWith(f, ".hx") ) {
				ensureScopeForFile(full, true);
				collectMetadataScopesForFile(full);
			}
		}
	}

	static function collectScopesFromClassPath() {
		if( classpathScanned )
			return;
		classpathScanned = true;
		var visited = new Map<String,Bool>();
		for( cp in Context.getClassPath() ) {
			var abs = ensureAbsolute(cp);
			if( !sys.FileSystem.exists(abs) || !sys.FileSystem.isDirectory(abs) )
				continue;
			scanClassPathRec(abs, visited);
		}
		ensureDefaultScope();
	}

	static function getCurrentScope() {
		var c = Context.getLocalClass();
		if( c == null )
			return ensureDefaultScope();
		var cls = c.get();
		var s = ensureScopeForClassType(cls, true);
		if( s == null )
			return ensureDefaultScope();
		return s;
	}

	static function shouldRewriteClass() {
		var c = Context.getLocalClass();
		if( c == null )
			return false;
		var cls = c.get();
		if( cls.isExtern )
			return false;
		var mod = cls.module;
		if( mod == "hxd.Res" || mod == "hxd.res.ScopedRes" )
			return false;
		if( StringTools.startsWith(mod, "hxd._res.") )
			return false;
		return true;
	}

	static function getImportedResIdentifiers() {
		var names = new Map<String,Bool>();
		for( imp in Context.getLocalImports() ) {
			var parts = [for( part in imp.path ) part.name];
			if( parts.length != 2 || parts[0] != "hxd" || parts[1] != "Res" )
				continue;
			switch( imp.mode ) {
			case INormal:
				names.set("Res", true);
			case IAsName(alias):
				names.set(alias, true);
			case IAll:
			}
		}
		return names;
	}

	static function isHxdResExpr( e : Expr, importedResIdentifiers : Map<String,Bool> ) {
		return switch( e.expr ) {
		case EField(base, "Res"):
			switch( base.expr ) {
			case EConst(CIdent("hxd")): true;
			default: false;
			}
		case EConst(CIdent(name)):
			importedResIdentifiers.exists(name);
		default:
			false;
		}
	}

	static function isHxdResLoaderExpr( e : Expr, importedResIdentifiers : Map<String,Bool> ) {
		return switch( e.expr ) {
		case EField(base, "loader"):
			isHxdResExpr(base, importedResIdentifiers);
		default:
			false;
		}
	}

	static function typePathExpr( tp : TypePath, pos : Position ) {
		var e : Expr = { expr : EConst(CIdent(tp.pack[0])), pos : pos };
		for( i in 1...tp.pack.length )
			e = { expr : EField(e, tp.pack[i]), pos : pos };
		return { expr : EField(e, tp.name), pos : pos };
	}

	static function identExpr( name : String, pos : Position ) : Expr {
		return { expr : EConst(CIdent(name)), pos : pos };
	}

	static function declareVar( name : String, value : Expr, ?t : ComplexType ) : Expr {
		return {
			expr : EVars([{
				name : name,
				type : t,
				expr : value,
			}]),
			pos : Context.currentPos(),
		};
	}

	static function rewriteExpr( e : Expr, scope : ScopeInfo, importedResIdentifiers : Map<String,Bool> ) : Expr {
		var mapped = ExprTools.map(e, function( sub ) return rewriteExpr(sub, scope, importedResIdentifiers));
		return switch( mapped.expr ) {
		case ECall(callTarget, args):
			switch( callTarget.expr ) {
			case EField(target, "load") if( isHxdResLoaderExpr(target, importedResIdentifiers) ):
				macro hxd.res.ScopedLoaders.get($v{scope.id}).loadScoped($a{args});
			case EField(target, "loadScoped") if( isHxdResLoaderExpr(target, importedResIdentifiers) ):
				macro hxd.res.ScopedLoaders.get($v{scope.id}).loadScoped($a{args});
			case EField(target, "existsScoped") if( isHxdResLoaderExpr(target, importedResIdentifiers) ):
				macro hxd.res.ScopedLoaders.get($v{scope.id}).existsScoped($a{args});
			case EField(target, "exists") if( isHxdResLoaderExpr(target, importedResIdentifiers) ):
				macro hxd.res.ScopedLoaders.get($v{scope.id}).exists($a{args});
			default:
				mapped;
			}
		case EField(target, f):
			if( isHxdResExpr(target, importedResIdentifiers) && !rewriteIgnoreFields.exists(f) )
				{ expr : EField(typePathExpr(scope.typePath, target.pos), f), pos : mapped.pos };
			else
				mapped;
		default:
			mapped;
		}
	}

	static function rewriteFields( fields : Array<Field>, scope : ScopeInfo, importedResIdentifiers : Map<String,Bool> ) {
		for( f in fields ) {
			switch( f.kind ) {
			case FFun(fun) if( fun.expr != null ):
				fun.expr = rewriteExpr(fun.expr, scope, importedResIdentifiers);
			case FVar(t, e) if( e != null ):
				f.kind = FVar(t, rewriteExpr(e, scope, importedResIdentifiers));
			case FProp(get, set, t, e) if( e != null ):
				f.kind = FProp(get, set, t, rewriteExpr(e, scope, importedResIdentifiers));
			default:
			}
		}
	}

	static function sortedScopes() {
		var scopes = [for( s in scopeByKey ) s];
		scopes.sort(function( a, b ) return Reflect.compare(a.id, b.id));
		return scopes;
	}

	static function sortedRoots() {
		var roots = [for( k in rootPathByKey.keys() ) ({ key : k, path : rootPathByKey.get(k) } : RootInfo)];
		roots.sort(function( a, b ) return Reflect.compare(a.key, b.key));
		return roots;
	}

	static function buildScopeLoaderExprs( fsVarPrefix : String ) : Array<Expr> {
		var exprs = [];
		var scopes = sortedScopes();
		for( s in scopes ) {
			var fsList = "__scopeFs_" + s.id;
			var fsExpr = identExpr(fsList, Context.currentPos());
			exprs.push(declareVar(fsList, macro []));
			var idx = s.rootKeys.length;
			while( idx > 0 ) {
				var rootKey = s.rootKeys[--idx];
				var rootVar = fsVarPrefix + rootKey;
				var rootExpr = identExpr(rootVar, Context.currentPos());
				exprs.push(macro $fsExpr.push($rootExpr));
			}
			var loaderVar = "__scopeLoader_" + s.id;
			var loaderExpr = macro new hxd.res.Loader($fsExpr.length == 1 ? cast $fsExpr[0] : new hxd.fs.MultiFileSystem(cast $fsExpr));
			exprs.push(declareVar(loaderVar, loaderExpr));
			var loaderRef = identExpr(loaderVar, Context.currentPos());
			exprs.push(macro hxd.res.ScopedLoaders.setScopeLoader($v{s.id}, $loaderRef));
		}
		var def = ensureDefaultScope();
		exprs.push(macro hxd.res.ScopedLoaders.setDefaultScope($v{def.id}));
		exprs.push(macro hxd.Res.loader = hxd.res.ScopedLoaders.getDefaultLoader());
		exprs.push(macro @:privateAccess cgd.Runtime.notifyResourcesLoaded());
		return exprs;
	}

	public static function buildRes() {
		setup();
		return new FileTree(null).buildFields();
	}

	public static function install() {
		setup();
	}

	public static function rewriteType() {
		setup();
		var fields = Context.getBuildFields();
		if( !shouldRewriteClass() )
			return fields;
		var scope = getCurrentScope();
		var importedResIdentifiers = getImportedResIdentifiers();
		rewriteFields(fields, scope, importedResIdentifiers);
		return fields;
	}

	public static function pakManifest() : Expr {
		setup();
		collectScopesFromClassPath();
		var entries = [];
		for( root in sortedRoots() )
			entries.push(macro { key : $v{root.key}, path : $v{root.path} });
		return macro $a{entries};
	}

	public static function initLocal( ?configuration : ExprOf<String> ) : Expr {
		setup();
		collectScopesFromClassPath();
		var cfg = constStringArg(configuration, "configuration");
		var exprs = [macro hxd.res.ScopedLoaders.clear()];
		for( root in sortedRoots() ) {
			var rootVar = "__rootFs_" + root.key;
			exprs.push(declareVar(rootVar, macro new hxd.fs.LocalFileSystem($v{root.path}, $v{cfg})));
		}
		exprs = exprs.concat(buildScopeLoaderExprs("__rootFs_"));
		return { expr : EBlock(exprs), pos : Context.currentPos() };
	}

	public static function initEmbed( ?options : ExprOf<hxd.res.EmbedOptions> ) : Expr {
		setup();
		collectScopesFromClassPath();
		var opts = options == null ? macro null : options;
		var exprs = [macro hxd.res.ScopedLoaders.clear()];
		for( root in sortedRoots() ) {
			var rootVar = "__rootFs_" + root.key;
			exprs.push(declareVar(rootVar, macro hxd.fs.EmbedFileSystem.create($v{root.path}, $opts, $v{root.key})));
		}
		exprs = exprs.concat(buildScopeLoaderExprs("__rootFs_"));
		return { expr : EBlock(exprs), pos : Context.currentPos() };
	}

	public static function initPak( ?file : ExprOf<String> ) : Expr {
		setup();
		collectScopesFromClassPath();
		var fileName = constStringArg(file, "file");
		if( fileName == null )
			fileName = Context.definedValue("resourcesPath");
		if( fileName == null )
			fileName = "res";

		var exprs = [macro hxd.res.ScopedLoaders.clear(), macro var file = $v{fileName}];

		for( root in sortedRoots() ) {
			var pakVar = "__pak_" + root.key;
			var hasVar = "__hasPak_" + root.key;
			var firstFile = "__pakFile_" + root.key;
			var pakExpr = identExpr(pakVar, Context.currentPos());
			var hasExpr = identExpr(hasVar, Context.currentPos());
			var firstExpr = identExpr(firstFile, Context.currentPos());
			exprs.push(declareVar(pakVar, macro new hxd.fmt.pak.FileSystem()));
			exprs.push(declareVar(hasVar, macro false));
			exprs.push(declareVar(firstFile, macro file + "." + $v{root.key} + ".pak"));
			exprs.push(macro if( hxd.File.exists($firstExpr) ) {
				$pakExpr.loadPak($firstExpr);
				$hasExpr = true;
				var i = 1;
				while( true ) {
					var add = file + "." + $v{root.key} + i + ".pak";
					if( !hxd.File.exists(add) ) break;
					$pakExpr.loadPak(add);
					i++;
				}
			});
		}

		exprs.push(macro var __legacyPak = new hxd.fmt.pak.FileSystem());
		exprs.push(macro var __hasLegacyPak = false);
		exprs.push(macro if( hxd.File.exists(file + ".pak") ) {
			__legacyPak.loadPak(file + ".pak");
			__hasLegacyPak = true;
			var i = 1;
			while( true ) {
				var add = file + i + ".pak";
				if( !hxd.File.exists(add) ) break;
				__legacyPak.loadPak(add);
				i++;
			}
		});

		for( s in sortedScopes() ) {
			var fsList = "__scopeFs_" + s.id;
			var fsExpr = identExpr(fsList, Context.currentPos());
			exprs.push(declareVar(fsList, macro []));
			var idx = s.rootKeys.length;
			while( idx > 0 ) {
				var key = s.rootKeys[--idx];
				var hasVar = "__hasPak_" + key;
				var pakVar = "__pak_" + key;
				var hasExpr = identExpr(hasVar, Context.currentPos());
				var pakExpr = identExpr(pakVar, Context.currentPos());
				exprs.push(macro if( $hasExpr ) $fsExpr.push($pakExpr));
			}
			exprs.push(macro if( $fsExpr.length == 0 && __hasLegacyPak ) $fsExpr.push(__legacyPak));
			exprs.push(macro if( $fsExpr.length == 0 ) throw "No pak file found for scope " + $v{s.id});
			var loaderVar = "__scopeLoader_" + s.id;
			var loaderExpr = macro new hxd.res.Loader($fsExpr.length == 1 ? cast $fsExpr[0] : new hxd.fs.MultiFileSystem(cast $fsExpr));
			exprs.push(declareVar(loaderVar, loaderExpr));
			var loaderRef = identExpr(loaderVar, Context.currentPos());
			exprs.push(macro hxd.res.ScopedLoaders.setScopeLoader($v{s.id}, $loaderRef));
		}

		var def = ensureDefaultScope();
		exprs.push(macro hxd.res.ScopedLoaders.setDefaultScope($v{def.id}));
		exprs.push(macro hxd.Res.loader = hxd.res.ScopedLoaders.getDefaultLoader());
		exprs.push(macro @:privateAccess cgd.Runtime.notifyResourcesLoaded());
		return { expr : EBlock(exprs), pos : Context.currentPos() };
	}
	#end

}
