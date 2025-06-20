package;

import haxe.io.Bytes;
import haxe.ds.StringMap;
import sys.io.File;
import sys.FileSystem;

class Tsukuru {

    public var snbprojPath: String;
    public var projDirPath: String;

    public var snbProjJson: SunabaProject;

    private var zipOutputPath: String;

    public var haxePath: String = "haxe"; // Default path to Haxe compiler

    public function new() {}

    public function build(snbprojPath: String): Void {
        Sys.println("Building project at: " + snbprojPath);
        // Here you would implement the logic to build the project
        // For now, we just print a message
        this.snbprojPath = snbprojPath;
        var snbProjPathArray = snbprojPath.split("/");
        this.projDirPath = snbProjPathArray.slice(0, snbProjPathArray.length - 1).join("/");
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
            var json = sys.io.File.getContent(snbprojPath);
            this.snbProjJson = haxe.Json.parse(json);
            Sys.println("Successfully loaded project JSON.");

            Sys.println("Project name: " + this.snbProjJson.name);
            Sys.println("Project version: " + this.snbProjJson.version);
            Sys.println("Project type: " + this.snbProjJson.type);
            Sys.println("Script directory: " + this.snbProjJson.scriptdir);
            Sys.println("API symbols enabled: " + this.snbProjJson.apisymbols);
            Sys.println("Source map enabled: " + this.snbProjJson.sourcemap);
            Sys.println("Entrypoint: " + this.snbProjJson.entrypoint);
            Sys.println("Lua binary: " + this.snbProjJson.luabin);
            Sys.println("Libraries: " + this.snbProjJson.libraries.join(", "));
            Sys.println("Compiler flags: " + this.snbProjJson.compilerFlags.join(", "));

            if (snbProjJson.type == "executable") {
                zipOutputPath = this.projDirPath + "/bin/" + this.snbProjJson.name + ".sbx";
            }
            else if (snbProjJson.type == "library") {
                zipOutputPath = this.projDirPath + "/bin/" + this.snbProjJson.name + ".sblib";
            } else {
                Sys.println("Unknown project type: " + this.snbProjJson.type);
                Sys.exit(1);
                return;
            }

            var command = this.generateHaxeBuildCommand();
            Sys.println("Generated Haxe build command: " + command);

            Sys.println("Output path for binary: " + zipOutputPath);

            var hxres = Sys.command(command);
            if (hxres != 0) {
                Sys.println("Haxe build command failed with exit code: " + hxres);
                Sys.exit(hxres);
                return;
            }

            Sys.println("Haxe build command executed successfully.");

            var mainLuaPath = this.projDirPath + "/" + this.snbProjJson.entrypoint;
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

            // Add main Lua file to the zip
            var entry:haxe.zip.Entry = {
                fileName: this.snbProjJson.entrypoint,
                fileTime: Date.now(),
                dataSize: mainLuaContent.length,
                fileSize: mainLuaContent.length,
                data: mainLuaContent,
                crc32: haxe.crypto.Crc32.make(mainLuaContent),
                compressed: false
            };
            entries.add(entry);

            var sourceMapName = this.snbProjJson.entrypoint + ".map";
            if (this.snbProjJson.sourcemap != false) {
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
                        compressed: true
                    };
                    entries.add(sourceMapEntry);
                } else {
                    Sys.println("Source map file does not exist, skipping: " + sourceMapName);
                }
            }
            if (this.snbProjJson.apisymbols != false) {
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
                        compressed: true
                    };
                    entries.add(typesXmlEntry);
                } else {
                    Sys.println("Types XML file does not exist, skipping.");
                }
            }

            // Add all asset files to the zip
            for (assetKey in assetKeys) {
                var assetContent = assets.get(assetKey);
                Sys.println("Adding asset file: assets/" + assetKey);
                var assetEntry:haxe.zip.Entry = {
                    fileName: "assets/" + assetKey,
                    fileSize: assetContent.length,
                    dataSize: assetContent.length,
                    fileTime: Date.now(),
                    data: assetContent,
                    crc32: haxe.crypto.Crc32.make(assetContent),
                    compressed: true
                };
                entries.add(assetEntry);
            }

            Sys.println("Adding libraries to the zip file.");
            
            
            writer.write(entries);
            // Close the output stream
            out.close();

            if (snbProjJson.type == "executable") {
                Sys.println("sbx file created successfully at: " + zipOutputPath);
            }
            else if (snbProjJson.type == "library") {
                Sys.println("sblib file created successfully at: " + zipOutputPath);
            }
            
        } catch (e: Dynamic) {
            Sys.println("Error loading project JSON: " + e);
            Sys.exit(1);
            return;
        }
    }

    private function generateHaxeBuildCommand(): String {
        var command = this.haxePath + " --class-path " + this.projDirPath + "/" + this.snbProjJson.scriptdir + " -main " + this.snbProjJson.entrypoint + " --library sunaba-core";
        if (this.snbProjJson.apisymbols != false) {
            command += " --xml " + this.projDirPath + "/types.xml";
        }
        if (this.snbProjJson.sourcemap != false) {
            command += " -D source-map";
        }
        command += " -lua " + this.projDirPath + "/" + this.snbProjJson.luabin += " -D lua-vanilla";

        var librariesStr = "";
        for (lib in this.snbProjJson.libraries) {
            librariesStr += " --library " + lib;
        }
        command += " " + this.snbProjJson.compilerFlags.join(" ");
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
                var content = File.getContent(filePath);
                assets.set(f, Bytes.ofString(content));
            }
        }

        return assets;
    }
}