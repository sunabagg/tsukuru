import haxe.ds.StringMap;

class WizMake {

    public var snbprojPath: String;
    public var projDirPath: String;

    public var snbProjJson: SunabaProject;

    private var zipOutputPath: String;

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
        if (!sys.io.FileSystem.exists(binPath)) {
            sys.io.FileSystem.createDirectory(binPath);
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
                return;
            }
            
        } catch (e: Dynamic) {
            Sys.println("Error loading project JSON: " + e);
            return;
        }
    }
}