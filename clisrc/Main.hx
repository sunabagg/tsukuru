package;

class Main {
    public static function main() {
        var args = Sys.args();
        if (args.length < 1 || args[0] == "-h" || args[0] == "--help") {
            Sys.println("Usage: tsukuru <project.snbproj>");
            return;
        }

        var tsukuru = new Tsukuru();

        var arg1 = args[1];
        if (arg1 == "-O") {
            var arg2 = args[2];
            tsukuru.zipOutputPath = arg2;
        }
        
        tsukuru.build(args[0]);
    }
}