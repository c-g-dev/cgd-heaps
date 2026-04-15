const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..");
const ICONS_DIR = path.join(ROOT_DIR, "res", "icons");
const OUTPUT_FILE = path.join(ROOT_DIR, "cgd", "GlobalIcons.hx");

const ICON_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);

function toResourceIdentifier(name) {
  return name.replace(/[^A-Za-z0-9]/g, "_");
}

function collectIconFiles(directory, relative = "") {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const relativePath = path.join(relative, entry.name);
    const absolutePath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      files.push(...collectIconFiles(absolutePath, relativePath));
      continue;
    }

    if (entry.isFile() && ICON_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) {
      files.push(relativePath);
    }
  }

  return files;
}

function buildItems(iconFiles) {
  const items = [];

  for (const relativePath of iconFiles) {
    const normalized = relativePath.replace(/\\/g, "/");
    const noExt = normalized.replace(/\.[^.]+$/i, "");
    const segments = noExt.split("/");

    if (segments.length === 0) {
      continue;
    }

    const fileBase = segments[segments.length - 1];
    const enumName = toResourceIdentifier(fileBase);
    const resSegments = segments.map(toResourceIdentifier);
    const resPath = "hxd.Res.icons." + resSegments.join(".");

    items.push({
      enumName,
      resPath,
    });
  }

  items.sort((a, b) => a.enumName.localeCompare(b.enumName));
  return items;
}

function renderGlobalIcons(items) {
  const enumLines = items
    .map((item) => `    public static inline var ${item.enumName}:GlobalIcons = "${item.enumName}";`)
    .join("\n");

  const mappingLines = items
    .map((item) => `            case ${item.enumName}: return ${item.resPath}.toTile();`)
    .join("\n");

  const allLines = items
    .map((item) => `            ${item.enumName}`)
    .join(",\n");

  return `package cgd;

import h2d.Tile;

enum abstract GlobalIcons(String) to String from String {
    //autogenerate from /res/icons (start)
${enumLines}
    //autogenerate from /res/icons (end)

    public function toTile():Tile {
        switch(this) {
            //autogenerate mapping to hxd.Res icon item (start)
${mappingLines}
            //autogenerate mapping to hxd.Res icon item (end)
        }
        throw 'Unknown GlobalIcons value: "${this}"';
    }

    public static function all(): Array<GlobalIcons> {
        return [
            //autogenerate all GlobalIcons values (start)
${allLines}
            //autogenerate all GlobalIcons values (end)
        ];
    }
}
`;
}

function main() {
  const iconFiles = collectIconFiles(ICONS_DIR);
  const items = buildItems(iconFiles);
  const content = renderGlobalIcons(items);
  fs.writeFileSync(OUTPUT_FILE, content, "utf8");
  console.log(`Generated ${OUTPUT_FILE} with ${items.length} icon entries.`);
}

main();
