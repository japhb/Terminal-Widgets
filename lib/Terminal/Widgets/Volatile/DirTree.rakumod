# ABSTRACT: A volatile data structure representing a live directory tree

unit module Terminal::Widgets::Volatile::DirTree;


role Node {
    has IO::Path:D() $.path is required;
    has Node         $.parent;


    #| Simplified gist that does not traverse parents
    method gist(::?CLASS:D:) {
        my $short-name = self.^name.subst('Terminal::Widgets::Volatile::', '');
        $short-name ~ ':' ~ $!path.path
    }

    #| Find root node via parent chain, runtime is O(depth)
    method root(::?CLASS:D:) {
        my $root = self;
        $root .= parent while $root.parent;
        $root
    }
}

class Dev does Node {
}

class File does Node {
}

class SymLink does Node {
    has IO::Path:D() $.target is required;


    #| Standard node gist plus target
    method gist(::?CLASS:D:) {
        self.Node::gist ~ ' => ' ~ $!target.path
    }
}

class Dir does Node {
    has Node:D    @!children   is built;
    has Instant:D $.cache-time .= from-posix-nanos(0);


    #| Lazily find (and cache) children, forcing a refresh if requested
    method children(::?CLASS:D: Bool:D :$refresh = False) {
        # XXXX: For now, just fake real caching and be lazy
        if $refresh || !$!cache-time {
            $!cache-time = now;
            @!children   = $!path.dir.map: {
                .d   ?? Dir.new(    parent => self, path => $_) !!
                .l   ?? SymLink.new(parent => self, path => $_, target => .readlink) !!
                .f   ?? File.new(   parent => self, path => $_) !!
                .dev ?? Dev.new(    parent => self, path => $_) !!
                        Node.new(   parent => self, path => $_) ;
            };
        }
        @!children
    }
}

class Root is Dir {
}
