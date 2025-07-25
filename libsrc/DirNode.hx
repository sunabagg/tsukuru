package;

class DirNode extends FsNode {
    public var children: Array<FsNode>;
    public function new() {
        super();
        this.children = []; 
    }
}
