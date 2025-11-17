# ABSTRACT: Base roles for volatile tree data structures

unit module Terminal::Widgets::Volatile::Tree;


#| Basic generic tree node that knows its parent (if any)
role Node {
    has Node $.parent;

    #| Shortened name for gists
    method gist-name() {
        self.^name.subst('Terminal::Widgets::', '')
    }

    #| Find root node via parent chain, runtime is O(depth)
    method root(::?CLASS:D:) {
        my $root = self;
        $root .= parent while $root.parent;
        $root
    }
}

#| A pure leaf node, no children ever
role Leaf does Node { }

#| A parent node, which MAY have children at any given time
role Parent does Node {
    #| REQUIRED: Lazily find (and maybe cache) children, forcing a refresh if requested
    method children(::?CLASS:D: Bool:D :$refresh = False) { ... }
}
