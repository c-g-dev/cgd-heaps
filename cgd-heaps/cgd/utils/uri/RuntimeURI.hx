package cgd.utils.uri;


/*
  These strings are explicitly typed so that we don't get confused.
*/


typedef RuntimeURIProtocol = String;
typedef RuntimeURIPath = String;

typedef RuntimeURIData = {
    var protocol: RuntimeURIProtocol;
    var path: RuntimeURIPath;
}

@:forward
abstract RuntimeURI(RuntimeURIData) {
    private static var DEFAULT_PROTOCOL: String = "myapp";

    public inline function new(uri: String) {
        this = {
            protocol: uri.indexOf("://") != -1 ? uri.substring(0, uri.indexOf("://")) : DEFAULT_PROTOCOL,
            path: uri.indexOf("://") != -1 ? uri.substring(uri.indexOf("://") + 3) : uri,
        };
    }
}