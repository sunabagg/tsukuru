package;

import haxe.io.Bytes;
import haxe.ds.StringMap;
import sys.io.File;
import sys.FileSystem;

class Lfxbuild {

    public var lfxprojPath: String;
    public var projDirPath: String;

    public var lfxprojJson: LucidfxProject;

    public var zipOutputPath: String = "";

    public var haxePath: String = "haxe"; // Default path to Haxe compiler

    public function new() {}

    public function build(lfxprojPath: String): Void {
        Sys.println("Building project at: " + lfxprojPath);

        lfxprojPath = FileSystem.absolutePath(lfxprojPath);

        // Here you would implement the logic to build the project
        // For now, we just print a message
        this.lfxprojPath = lfxprojPath;
        var lfxprojPathArray = lfxprojPath.split("/");
        this.projDirPath = lfxprojPathArray.slice(0, lfxprojPathArray.length - 1).join("/");
        Sys.println("Project directory path: " + this.projDirPath);
        var binPath = this.projDirPath + "/bin";
        if (!FileSystem.exists(binPath)) {
            FileSystem.createDirectory(binPath);
            Sys.println("Created bin directory: " + binPath);
        } else {
            Sys.println("Bin directory already exists: " + binPath);
        }

        // Load the XML project file
        try {
            var json = sys.io.File.getContent(lfxprojPath);
            this.lfxprojJson = haxe.Json.parse(json);
            Sys.println("Successfully loaded project JSON.");

            Sys.println("Project name: " + this.lfxprojJson.name);
            Sys.println("Project version: " + this.lfxprojJson.version);
            Sys.println("Project type: " + this.lfxprojJson.type);
            Sys.println("Script directory: " + this.lfxprojJson.scriptdir);
            Sys.println("API symbols enabled: " + this.lfxprojJson.apisymbols);
            Sys.println("Source map enabled: " + this.lfxprojJson.sourcemap);
            Sys.println("Entrypoint: " + this.lfxprojJson.entrypoint);
            Sys.println("Lua binary: " + this.lfxprojJson.luabin);
            Sys.println("Libraries: " + this.lfxprojJson.libraries.join(", "));
            Sys.println("Compiler flags: " + this.lfxprojJson.compilerFlags.join(", "));

            if (lfxprojJson.type == "executable") {
                if (zipOutputPath == "") {
                    zipOutputPath = this.projDirPath + "/bin/" + this.lfxprojJson.name + ".sbx";
                }
                else if (StringTools.endsWith(zipOutputPath, ".ldll")) {
                    Sys.println("Warning: Output path ends with .ldll, changing to .sbx");
                    zipOutputPath = StringTools.replace(zipOutputPath, ".ldll", ".sbx");
                }
                else if (StringTools.endsWith(zipOutputPath, ".sbx")) {
                    // Do nothing, already correct
                }
                else {
                    zipOutputPath += ".sbx";
                }
            }
            else if (lfxprojJson.type == "library") {
                if (zipOutputPath == "") {
                    zipOutputPath = this.projDirPath + "/bin/" + this.lfxprojJson.name + ".ldll";
                }
                else if (StringTools.endsWith(zipOutputPath, ".sbx")) {
                    Sys.println("Warning: Output path ends with .sbx, changing to .ldll");
                    zipOutputPath = StringTools.replace(zipOutputPath, ".sbx", ".ldll");
                }
                else if (StringTools.endsWith(zipOutputPath, ".ldll")) {
                    // Do nothing, already correct
                }
                else {
                    zipOutputPath += ".ldll";
                }
            } else {
                Sys.println("Unknown project type: " + this.lfxprojJson.type);
                Sys.exit(1);
                return;
            }

            var command = this.generateHaxeBuildCommand();
            Sys.println("Generated Haxe build command: " + command);

            Sys.println("Output path for binary: " + zipOutputPath);

            var hxres = Sys.command("cd " + this.projDirPath + " && " + command);
            if (hxres != 0) {
                Sys.println("Haxe build command failed with exit code: " + hxres);
                Sys.exit(hxres);
                return;
            }

            Sys.println("Haxe build command executed successfully.");

            var mainLuaPath = this.projDirPath + "/" + this.lfxprojJson.luabin;
            if (!FileSystem.exists(mainLuaPath)) {
                Sys.println("Main Lua file does not exist: " + mainLuaPath);
                Sys.exit(1);
                return;
            }

            Sys.println("Reading main Lua file: " + mainLuaPath);
            var mainLuaContent = File.getBytes(mainLuaPath);

            var assets = this.getAllFiles(this.projDirPath + "/assets");

            var assetKeys = [];
            for (k in assets.keys()) assetKeys.push(k);
            Sys.println("Found " + assetKeys.length + " asset files in the project.");

            // Create the zip file using haxe.zip.Writer
            Sys.println("Creating zip file at: " + zipOutputPath);
            var out = sys.io.File.write(zipOutputPath, true);
            var writer = new haxe.zip.Writer(out);

            // Collect all zip entries in a list
            var entries = new haxe.ds.List<haxe.zip.Entry>();

            Sys.println("Adding main Lua file to zip: " + this.lfxprojJson.luabin);
            // Add main Lua file to the zip
            var entry:haxe.zip.Entry = {
                fileName: this.lfxprojJson.luabin,
                fileTime: Date.now(),
                dataSize: mainLuaContent.length,
                fileSize: mainLuaContent.length,
                data: mainLuaContent,
                crc32: haxe.crypto.Crc32.make(mainLuaContent),
                compressed: false
            };
            entries.add(entry);

            if (this.lfxprojJson.sourcemap != false) {
                var sourceMapName = this.lfxprojJson.luabin + ".map";
                var sourceMapPath = this.projDirPath + "/" + sourceMapName;
                if (FileSystem.exists(sourceMapPath)) {
                    Sys.println("Adding source map file: " + sourceMapName);
                    var sourceMapContent = File.getBytes(sourceMapPath);
                    var sourceMapEntry:haxe.zip.Entry = {
                        fileName: sourceMapName,
                        fileSize: sourceMapContent.length,
                        dataSize: sourceMapContent.length,
                        fileTime: Date.now(),
                        data: sourceMapContent,
                        crc32: haxe.crypto.Crc32.make(sourceMapContent),
                        compressed: false
                    };
                    entries.add(sourceMapEntry);
                } else {
                    Sys.println("Source map file does not exist, skipping: " + sourceMapName);
                }
            }
            if (this.lfxprojJson.apisymbols != false) {
                var typesXmlPath = this.projDirPath + "/types.xml";
                if (FileSystem.exists(typesXmlPath)) {
                    Sys.println("Adding types XML file: types.xml");
                    var typesXmlContent = File.getBytes(typesXmlPath);
                    var typesXmlEntry:haxe.zip.Entry = {
                        fileName: "types.xml",
                        fileSize: typesXmlContent.length,
                        dataSize: typesXmlContent.length,
                        fileTime: Date.now(),
                        data: typesXmlContent,
                        crc32: haxe.crypto.Crc32.make(typesXmlContent),
                        compressed: false
                    };
                    entries.add(typesXmlEntry);
                } else {
                    Sys.println("Types XML file does not exist, skipping.");
                }
            }

            // Add all asset files to the zip
            for (assetKey in assetKeys) {
                var assetContent = assets.get(assetKey);
                Sys.println("Adding asset file: " + assetKey);
                var assetEntry:haxe.zip.Entry = {
                    fileName: assetKey,
                    fileSize: assetContent.length,
                    dataSize: assetContent.length,
                    fileTime: Date.now(),
                    data: assetContent,
                    crc32: haxe.crypto.Crc32.make(assetContent),
                    compressed: false
                };
                entries.add(assetEntry);
            }

            Sys.println("creating header for zip file");

            var header : HeaderFile = {
                name: this.lfxprojJson.name,
                version: this.lfxprojJson.version,
                rootUrl: this.lfxprojJson.rootUrl,
                luabin: this.lfxprojJson.luabin,
                type: this.lfxprojJson.type
            };

            var headerJson = haxe.Json.stringify(header);
            Sys.println("Adding header to zip file: header.json");
            var headerContent = haxe.io.Bytes.ofString(headerJson);
            var headerEntry:haxe.zip.Entry = {
                fileName: "header.json",
                fileSize: headerContent.length,
                dataSize: headerContent.length,
                fileTime: Date.now(),
                data: headerContent,
                crc32: haxe.crypto.Crc32.make(headerContent),
                compressed: false
            };
            entries.add(headerEntry);
            

            writer.write(entries);
            // Close the output stream
            out.close();

            if (lfxprojJson.type == "executable") {
                Sys.println("sbx file created successfully at: " + zipOutputPath);
            }
            else if (lfxprojJson.type == "library") {
                Sys.println("ldll file created successfully at: " + zipOutputPath);
            }
            
        } catch (e: Dynamic) {
            Sys.println("Error loading project JSON: " + e);
            Sys.exit(1);
            return;
        }
    }

    private function generateHaxeBuildCommand(): String {
        var command = this.haxePath + " --class-path " + this.projDirPath + "/" + this.lfxprojJson.scriptdir + " -main " + this.lfxprojJson.entrypoint + " --library lucidfx";
        if (this.lfxprojJson.apisymbols != false) {
            command += " --xml " + this.projDirPath + "/types.xml";
        }
        if (this.lfxprojJson.sourcemap != false) {
            command += " -D source-map";
        }
        command += " -lua " + this.projDirPath + "/" + this.lfxprojJson.luabin += " -D lua-vanilla";

        var librariesStr = "";
        for (lib in this.lfxprojJson.libraries) {
            librariesStr += " --library " + lib;
        }
        command += " " + this.lfxprojJson.compilerFlags.join(" ");
        return command;
    }

    private function getAllFiles(dir:String): StringMap<Bytes> {
        if (!FileSystem.exists(dir)) {
            throw "Directory does not exist: " + dir;
        }

        var vdir = StringTools.replace(dir, this.projDirPath, "");

        var assets = new StringMap<Bytes>();

        for (f in FileSystem.readDirectory(dir)) {
            var filePath = dir + "/" + f;
            if (FileSystem.isDirectory(filePath)) {
                // Recursively get files from subdirectory
                var subAssets = getAllFiles(filePath);
                for (key in subAssets.keys()) {
                    assets.set(key, subAssets.get(key));
                }
            } else {
                // Read file content
                var content = File.getBytes(filePath);
                var vfilePath = StringTools.replace(filePath, this.projDirPath, "");
                if (StringTools.startsWith(vfilePath, "/")) {
                    vfilePath = vfilePath.substr(1);
                }
                //Sys.println("Adding file to assets: " + vfilePath);
                assets.set(vfilePath, content);
            }
        }

        return assets;
    }
}