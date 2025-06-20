class WizMake {

    public var snbprojPath: String;
    public var projDirPath: String;

    public var snbProjXml: Xml;

    public function new() {}

    public function build(snbprojPath: String): Void {
        Sys.println("Building project at: " + snbprojPath);
        // Here you would implement the logic to build the project
        // For now, we just print a message
        this.snbprojPath = snbprojPath;
        var snbProjPathArray = snbprojPath.split("/");
        this.projDirPath = snbProjPathArray.slice(0, snbProjPathArray.length - 1).join("/");
        Sys.println("Project directory path: " + this.projDirPath);

        // Load the XML project file
        try {
            this.snbProjXml = Xml.parse(sys.io.File.getContent(snbprojPath));
            Sys.println("Successfully loaded project XML.");
        } catch (e: Dynamic) {
            Sys.println("Error loading project XML: " + e);
            return;
        }
    }
}