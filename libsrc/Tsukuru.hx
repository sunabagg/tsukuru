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