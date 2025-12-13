# ABSTRACT: Base roles for volatile tree data structures

unit module Terminal::Widgets::Volatile::Tree;

use Terminal::Widgets::Common;


#| Basic generic tree node that knows its parent (if any)
role Node does Terminal::Widgets::Common {
    has Node $.parent;

    #| REQUIRED: Short name for display, usually unique within siblings
    method short-name() { ... }

    #| REQUIRED: Long name for display, usually unique within entire tree
    method long-name() { ... }

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

    #| OPTIONAL: Identifier unique at least among all Parent nodes
    #| If missing, viewers won't remember expanded states of descendents
    #| of collapsed parent nodes.
    method id() { }
}


### STATIC TREE WRAPPING

#| A static leaf node
class StaticLeaf does Leaf {
    has $.source;
    has $!short-name is built;
    has $!long-name  is built;

    method short-name() { $!short-name //= $.source ~~ Cool
                                           ?? ~$.source
                                           !! $.source.?short-name // $.source.gist }
    method long-name()  { $!long-name  //=    $.source.?long-name  // $.source.raku }
}

#| A parent node whose children do NOT change
class StaticParent does Parent {
    has @.children;
    has $!short-name is built;
    has $!long-name  is built;

    method set-children(@!children) { }

    method short-name() { $!short-name //= $!parent ?? 'parent of ' ~ @.children.elems
                                                    !! 'root' }
    method long-name()  { $!long-name  //= self.raku }
}

#| Helper sub to wrap a static tree that has Positionals as parent nodes;
#| Pairs are named nodes
our sub static-tree($source-node, *%attrs) is export {
    do given $source-node {
        when Node       { $_ }
        when Pair       { static-tree(.value, |%attrs, short-name => .key) }
        when Positional {
            my $parent   = StaticParent.new(|%attrs);
            my @children = .map({ static-tree($_, :$parent) });
            $parent.set-children(@children);
            $parent
        }
        default {
            StaticLeaf.new(source => $_, |%attrs)
        }
    }
}
