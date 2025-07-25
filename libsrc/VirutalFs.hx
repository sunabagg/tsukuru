package;

class VirtualFs {
    public var root: DirNode;
    public var files: Map<Int, String> = new Map();

    public function new() {
        root = new DirNode();
    }
}
