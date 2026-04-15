class BuildPaks {

	static function main() {
		var manifest = hxd.Res.pakManifest();
		for( entry in manifest )
			hxd.fmt.pak.Build.make(entry.path, "tests/scoped_res/out/res." + entry.key);
	}

}
