package;

typedef SunabaProject = {
    var name: String;
    var version: String;
    var rootUrl: String;
    var type: String;
    var scriptdir: String;
    var apisymbols: Bool;
    var sourcemap: Bool;
    var entrypoint: String;
    var luabin: String;
    var libraries: Array<String>;
    var compilerFlags: Array<String>;
}