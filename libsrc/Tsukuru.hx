package;

import haxe.io.Bytes;
import haxe.ds.StringMap;
import sys.io.File;
import sys.FileSystem;

class Tsukuru {

    public var snbprojPath: String;
    public var projDirPath: String;

    public var snbProjJson: SunabaProject;

    public var zipOutputPath: String = "";

    public var haxePath: String = "haxe"; // Default path to Haxe compiler

    public function new() {}

    public function build(snbprojPath: String): Void {
        Sys.println("Building project at: " + snbprojPath);

        snbprojPath = FileSystem.absolutePath(snbprojPath);

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
            Sys.println("Assets directory: " + this.snbProjJson.assetsdir);
            Sys.println("API symbols enabled: " + this.snbProjJson.apisymbols);
            Sys.println("Source map enabled: " + this.snbProjJson.sourcemap);
            Sys.println("Entrypoint: " + this.snbProjJson.entrypoint);
            Sys.println("Lua binary: " + this.snbProjJson.luabin);
            Sys.println("Libraries: " + this.snbProjJson.libraries.join(", "));
            Sys.println("Compiler flags: " + this.snbProjJson.compilerFlags.join(", "));

            if (snbProjJson.type == "executable") {
                if (zipOutputPath == "") {
                    zipOutputPath = this.projDirPath + "/bin/" + this.snbProjJson.name + ".sbx";
                }
                else if (StringTools.endsWith(zipOutputPath, ".sblib")) {
                    Sys.println("Warning: Output path ends with .sblib, changing to .sbx");
                    zipOutputPath = StringTools.replace(zipOutputPath, ".sblib", ".sbx");
                }
                else if (StringTools.endsWith(zipOutputPath, ".sbx")) {
                    // Do nothing, already correct
                }
                else {
                    zipOutputPath += ".sbx";
                }
            }
            else if (snbProjJson.type == "library") {
                if (zipOutputPath == "") {
                    zipOutputPath = this.projDirPath + "/bin/" + this.snbProjJson.name + ".sblib";
                }
                else if (StringTools.endsWith(zipOutputPath, ".sbx")) {
                    Sys.println("Warning: Output path ends with .sbx, changing to .sblib");
                    zipOutputPath = StringTools.replace(zipOutputPath, ".sbx", ".sblib");
                }
                else if (StringTools.endsWith(zipOutputPath, ".sblib")) {
                    // Do nothing, already correct
                }
                else {
                    zipOutputPath += ".sblib";
                }
            } else {
                Sys.println("Unknown project type: " + this.snbProjJson.type);
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

            var mainLuaPath = this.projDirPath + "/" + this.snbProjJson.luabin;
            if (!FileSystem.exists(mainLuaPath)) {
                Sys.println("Main Lua file does not exist: " + mainLuaPath);
                Sys.exit(1);
                return;
            }

            Sys.println("Reading main Lua file: " + mainLuaPath);
            var mainLuaContent = File.getBytes(mainLuaPath);

            // Create the zip file using haxe.zip.Writer
            Sys.println("Creating zip file at: " + zipOutputPath);
            var out = sys.io.File.write(zipOutputPath, true);
            var writer = new haxe.zip.Writer(out);

            // Collect all zip entries in a list
            var entries = new haxe.ds.List<haxe.zip.Entry>();

            Sys.println("Adding main Lua file to zip: " + this.snbProjJson.luabin);
            // Add main Lua file to the zip
            var entry:haxe.zip.Entry = {
                fileName: this.snbProjJson.luabin,
                fileTime: Date.now(),
                dataSize: mainLuaContent.length,
                fileSize: mainLuaContent.length,
                data: mainLuaContent,
                crc32: haxe.crypto.Crc32.make(mainLuaContent),
                compressed: false
            };
            entries.add(entry);
            FileSystem.deleteFile(mainLuaPath);

            if (this.snbProjJson.sourcemap != false) {
                var sourceMapName = this.snbProjJson.luabin + ".map";
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
                    FileSystem.deleteFile(sourceMapPath);
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
                        compressed: false
                    };
                    entries.add(typesXmlEntry);
                    FileSystem.deleteFile(typesXmlPath);
                } else {
                    Sys.println("Types XML file does not exist, skipping.");
                }
            }


            var assetPath = this.projDirPath + "/" + this.snbProjJson.assetsdir;
            if (FileSystem.exists(assetPath)) {
                var assets = this.getAllFiles(assetPath);

                var assetKeys = [];
                for (k in assets.keys()) assetKeys.push(k);
                Sys.println("Found " + assetKeys.length + " asset files in the project.");

                // Add all asset files to the zip
                for (assetKey in assetKeys) {
                    var assetContent = assets.get(assetKey);
                    Sys.println("Adding asset file: " + assetKey);
                    var assetEntry:haxe.zip.Entry = {
                        fileName: StringTools.replace(assetKey, "assets/", ""),
                        fileSize: assetContent.length,
                        dataSize: assetContent.length,
                        fileTime: Date.now(),
                        data: assetContent,
                        crc32: haxe.crypto.Crc32.make(assetContent),
                        compressed: false
                    };
                    entries.add(assetEntry);
                }
            }
            

            Sys.println("creating header for zip file");

            var header : HeaderFile = {
                name: this.snbProjJson.name,
                version: this.snbProjJson.version,
                rootUrl: this.snbProjJson.rootUrl,
                luabin: this.snbProjJson.luabin,
                type: this.snbProjJson.type
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

            //var zipStr = File.getContent(zipOutputPath);
            //zipStr = "#!/usr/bin/env sunaba\n" + zipStr;
            //File.saveBytes(zipOutputPath, haxe.io.Bytes.ofString(zipStr));

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
        var command = this.haxePath + " --class-path " + this.projDirPath + "/" + this.snbProjJson.scriptdir + " -main " + this.snbProjJson.entrypoint + " --library sunaba";
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