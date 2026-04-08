package cgd.utils.uri;

import cgd.utils.uri.RuntimeURI.RuntimeURIPath;



interface RuntimeLocatorProtocol {
    function locate(uri: String): Dynamic;
    function inject(uri: String, value: Dynamic): Void;
}


class RuntimeLocatorProtocolImpl implements RuntimeLocatorProtocol {
    var data: Map<RuntimeURIPath, Dynamic>;
    public function new() {
        data = new Map<RuntimeURIPath, Dynamic>();
    }

    public function locate(uri: String): Dynamic {
        return data.get(new RuntimeURI(uri).path);
    }

    public function inject(uri: String, value: Dynamic): Void {
        var runtimeURI = new RuntimeURI(uri);
        data.set(runtimeURI.path, value);
    }
}