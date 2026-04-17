package;

import cgd.Runtime;
import cgd.utils.uri.RuntimeURI;
import cgd.utils.uri.RuntimeLocatorProtocol;

class Main {
    static function main() {
        trace("Starting RuntimeURI tests...");
        testRuntimeURI();
        testRuntimeLocatorProtocol();
        testRuntime();
        trace("All tests passed successfully!");
    }

    static function testRuntimeURI() {
        var uri1 = new RuntimeURI("myapp://data/file.txt");
        if (uri1.protocol != "myapp") throw 'Expected protocol "myapp", got "${uri1.protocol}"';
        if (uri1.path != "data/file.txt") throw 'Expected path "data/file.txt", got "${uri1.path}"';

        var uri2 = new RuntimeURI("http://example.com/api");
        if (uri2.protocol != "http") throw 'Expected protocol "http", got "${uri2.protocol}"';
        if (uri2.path != "example.com/api") throw 'Expected path "example.com/api", got "${uri2.path}"';

        var uri3 = new RuntimeURI("just_a_path.txt");
        if (uri3.protocol != "myapp") throw 'Expected default protocol "myapp", got "${uri3.protocol}"';
        if (uri3.path != "just_a_path.txt") throw 'Expected path "just_a_path.txt", got "${uri3.path}"';
    }

    static function testRuntimeLocatorProtocol() {
        var locator = new RuntimeLocatorProtocolImpl();
        
        locator.inject("test://foo/bar", "baz");
        var result = locator.locate("test://foo/bar");
        if (result != "baz") throw 'Expected "baz", got "$result"';

        // Check if just the path works since the locator uses the path as the map key
        var result2 = locator.locate("other://foo/bar");
        if (result2 != "baz") throw 'Expected "baz" (since path is the same), got "$result2"';

        var result3 = locator.locate("test://not/found");
        if (result3 != null) throw 'Expected null, got "$result3"';
    }

    static function testRuntime() {
        // Register a resolver
        var testResolver = new RuntimeLocatorProtocolImpl();
        Runtime.addProtocolResolver("test", testResolver);

        // Inject a value
        Runtime.inject("test://some/path", "test_value");

        // Locate the value
        var result = Runtime.locate("test://some/path");
        if (result != "test_value") throw 'Expected "test_value", got "$result"';
    }
}