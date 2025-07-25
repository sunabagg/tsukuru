package;

class VirtualFs {
    public var root: DirNode;
    public var ids: Array<Int> = [];
    public var fileContents: Array<String> = [];

    public function new() {
        root = new DirNode();
    }
}
