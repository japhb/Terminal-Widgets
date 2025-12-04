# ABSTRACT: A volatile data structure representing a live directory tree

unit module Terminal::Widgets::Volatile::DirTree;

use Terminal::Widgets::Volatile::Tree;

constant VTree = Terminal::Widgets::Volatile::Tree;


role PathContainer {
    has IO::Path:D() $.path is required;

    #| Short name: just the basename
    method short-name() { $!path.basename }

    #| Long name: full resolved path
    method long-name() { $!path.resolve }

    #| Simplified gist that does not traverse parents, and includes path
    method gist(::?CLASS:D:) {
        self.gist-name ~ ':' ~ $!path.path
    }
}

role Node   does VTree::Node   does PathContainer { }
role Leaf   does VTree::Leaf   does PathContainer { }
role Parent does VTree::Parent does PathContainer { }

class Misc does Node { }
class File does Leaf { }
class Dev  does Node { }

class SymLink does Node {
    has IO::Path:D() $.target is required;


    #| Standard node gist plus target
    method gist(::?CLASS:D:) {
        self.Node::gist ~ ' => ' ~ $!target.path
    }
}

class Dir does Parent {
    has VTree::Node:D @!children   is built;
    has Instant:D     $.cache-time .= from-posix-nanos(0);

    #| Identifier unique at least among all Parent nodes
    method id() { $!path.resolve }

    #| Lazily find (and cache) children, forcing a refresh if requested
    method children(::?CLASS:D: Bool:D :$refresh = False) {
        # XXXX: For now, just fake real caching and be lazy
        if $refresh || !$!cache-time {
            $!cache-time = now;

            # Directory read may fail due to insufficient permissions
            try my @entries = $!path.dir;

            @!children = @entries.map({ dir-tree-node($_, parent => self) });
        }
        @!children
    }
}

sub dir-tree-node(IO::Path:D() $path, VTree::Node :$parent) is export {
    with $path {
        .l   ?? SymLink.new(:$parent, path => $_, target => .readlink) !!
        .d   ?? Dir.new(    :$parent, path => $_) !!
        .f   ?? File.new(   :$parent, path => $_) !!
        .dev ?? Dev.new(    :$parent, path => $_) !!
                Misc.new(   :$parent, path => $_) ;
    }
}
