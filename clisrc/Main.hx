package;

class Main {
    public static function main() {
        var args = Sys.args();
        if (args.length < 1 || args[0] == "-h" || args[0] == "--help") {
            Sys.println("Usage: lfxbuild <project.lfxproj>");
            return;
        }

        var lfxbuild = new Lfxbuild();

        var arg1 = args[1];
        if (arg1 == "-O") {
            var arg2 = args[2];
            lfxbuild.zipOutputPath = arg2;
        }
        
        lfxbuild.build(args[0]);
    }
}