const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..");
const FONTS_DIR = path.join(ROOT_DIR, "res", "fonts");
const OUTPUT_FILE = path.join(ROOT_DIR, "cgd", "GlobalFonts.hx");

function toResourceIdentifier(name) {
  return name.replace(/[^A-Za-z0-9]/g, "_");
}

function collectFontFiles(directory, relative = "") {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const relativePath = path.join(relative, entry.name);
    const absolutePath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      files.push(...collectFontFiles(absolutePath, relativePath));
      continue;
    }

    if (entry.isFile() && path.extname(entry.name).toLowerCase() === ".fnt") {
      files.push(relativePath);
    }
  }

  return files;
}

function buildItems(fontFiles) {
  const items = [];

  for (const relativePath of fontFiles) {
    const normalized = relativePath.replace(/\\/g, "/");
    const noExt = normalized.replace(/\.fnt$/i, "");
    const segments = noExt.split("/");

    if (segments.length === 0) {
      continue;
    }

    const fileBase = segments[segments.length - 1];

    const enumNameRaw = fileBase;
    const enumName = toResourceIdentifier(enumNameRaw);

    const resSegments = segments.map(toResourceIdentifier);
    const resPath = "hxd.Res.fonts." + resSegments.join(".");

    items.push({
      enumName,
      resPath,
    });
  }

  items.sort((a, b) => a.enumName.localeCompare(b.enumName));
  return items;
}

function renderGlobalFonts(items) {
  const enumLines = items
    .map((item) => `    public static inline var ${item.enumName}:GlobalFonts = "${item.enumName}";`)
    .join("\n");

  const mappingLines = items
    .map((item) => `            case ${item.enumName}: return ${item.resPath}.toFont();`)
    .join("\n");

  const allLines = items
    .map((item) => `            ${item.enumName}`)
    .join(",\n");

  return `package cgd;

import h2d.Font;

enum abstract GlobalFonts(String) to String from String {
    //autogenerate from /res/fonts (start)
${enumLines}
    //autogenerate from /res/fonts (end)

    public function toFont():Font {
        switch(this) {
            //autogenerate mapping to hxd.Res font item (start)
${mappingLines}
            //autogenerate mapping to hxd.Res font item (end)
        }
        return hxd.res.DefaultFont.get();
    }

    public static function all(): Array<GlobalFonts> {
        return [
            //autogenerate all GlobalFonts values (start)
${allLines}
            //autogenerate all GlobalFonts values (end)
        ];
    }
}
`;
}

function main() {
  const fontFiles = collectFontFiles(FONTS_DIR);
  const items = buildItems(fontFiles);
  const content = renderGlobalFonts(items);
  fs.writeFileSync(OUTPUT_FILE, content, "utf8");
  console.log(`Generated ${OUTPUT_FILE} with ${items.length} font entries.`);
}

main();
