package;

class Main {
    public static function main() {
        var args = Sys.args();
        if (args.length < 1 || args[0] == "--help" || args[0] == "-h") {
            Sys.println("Usage: snbmake <project.snbproj>");
            return;
        }

        var tsukuru = new Tsukuru();
        tsukuru.build(args[0]);
    }
}