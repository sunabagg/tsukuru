class Main {
    public static function main() {
        var args = Sys.args();
        if (args.length < 1) {
            Sys.println("Usage: snbmake <project.snbproj>");
            return;
        }

        var wizMake = new WizMake();
        wizMake.build(args[0]);
    }
}