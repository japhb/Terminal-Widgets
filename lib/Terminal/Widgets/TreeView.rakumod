# ABSTRACT: A text widget that has clickable lines / a selected line.

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::SpanWrappingAndHighlighting;

role Terminal::Widgets::TreeViewNode {
    #| A single line of text for this node.
    has Str $.text;

    #| Some identifier. Can be any object.
    #| Optional in RichTreeViewNodes, mandatory in ShallowTreeViewNodes.
    #| Providing an ID for each node will allow saving and restoring
    #| the state of each node more reliably in the case of a changing tree
    #| structure.
    has $.id;

    method id-for-props() {
        $!id
    }

    method leaf(--> Bool) { ... }
}

role Terminal::Widgets::ShallowTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| Optional. If set to True, the node will hide the "expand" marker
    #| of the node, even if it wasn't opened yet.
    has Bool $!leaf is built = False;
    method leaf(--> Bool) { $!leaf }
}

role Terminal::Widgets::RichTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| This nodes children. If empty, it's a leaf node.
    has Terminal::Widgets::RichTreeViewNode @.children;
    method leaf(--> Bool) { @!children.elems == 0 }
}


class Terminal::Widgets::TreeView
 does Terminal::Widgets::SpanWrappingAndHighlighting
 does Terminal::Widgets::Focusable {
    my class NodeProperties {
        has $.id;
        has Bool $.expanded is rw;
    }

    my class DisplayNode {
        has Terminal::Widgets::TreeViewNode $.node;
        has DisplayNode @.children;
        has Int $.depth;
        has DisplayNode $.parent is rw;

        submethod TWEAK() {
            $_.parent = self for @!children;
        }

        method child-line-count() {
            [+] @!children.map: { 1 + $_.child-line-count }
        }
    }

    my class WrappedRichNode
      does Terminal::Widgets::ShallowTreeViewNode {
        has Terminal::Widgets::RichTreeViewNode $.orig;

        method id-for-props() {
            $!orig.id // $!id
        }
        method id-for-children() {
            $!id
        }
    }

    #| A function that will, when given a node ID, will return a list of that
    #| nodes children. When passed Nil as the node ID, it must return the top
    #| level nodes.
    #| sub get-children($node-id --> List[ShallowTreeViewNodes])
    has &.get-children;

    #| Alternatively to &.get-children, one can just pass a complete
    #| RichTreeViewNode list.
    has Terminal::Widgets::RichTreeViewNode $.root-node;

    #| DisplayNode trees. Contains a list of all visible nodes. Not necessarily
    #| on the screen, but not hidden in a collapsed parent.
    has $!dn-root;

    #| Node 
    has NodeProperties @.node-props;

    has &.get-node-prefix;

    has &.process-click;

    submethod TWEAK(:$wrap, :$root-node = Any, :$get-children = Any, :$get-node-prefix = Any) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;

        self.init-focusable;

        die '$root-node and &get-children can not be set both' if $root-node.defined && $get-children.defined;

        if !$get-children.defined && !$root-node.defined {
            self.set-root-node: Terminal::Widgets::RichTreeViewNode.new;
        }
        elsif $root-node.defined {
            self.set-root-node: $root-node;
        }
        elsif $get-children.defined {
            &!get-children = &$get-children;
        }


        if $get-node-prefix.defined {
            &!get-node-prefix = &$get-node-prefix;
        }
        else {
            &!get-node-prefix = sub (Int $level, Bool $expanded, Bool $leaf, Bool $last) {
                ($level == 0
                    ?? ''
                    !! ' ' x ($level - 1)
                        ~ ($last ?? '└' !! '├')
                )
                ~ ($leaf
                    ?? ' '
                    !! ($expanded ?? '⮟' !! '⮞')
                )
                ~ ' '
            }
        }

        self!refresh-dn;
    }

    method dn-get-text($dn) {
        my $expanded = self!prop-for-node($dn.node).expanded;
        &!get-node-prefix($dn.depth, $expanded, $dn.node.leaf, $dn === $dn.parent.children.end) ~ $dn.node.text;
    }

    sub get-children-of-tree($root-node, $id) {
        # In a wrapped tree, we'll populate the ID with a list of indexes
        # leading to the node.
        my $n = $root-node;
        my @ids;
        if !($id === Nil) {
            for @$id -> $index {
                $n = $n.children[$index];
            }
            @ids = @$id;
        }
        $n.children.kv.map: -> $i, $node {
            WrappedRichNode.new:
                id => (|@ids, $i),
                orig => $node,
                leaf => $node.children.elems == 0,
                text => $node.text,
            ;
        }
    }

    method set-root-node($!root-node) {
        &!get-children = sub ($id) {
            get-children-of-tree($!root-node, $id);
        }
        self!refresh-dn;
    }

    method set-get-children(&!get-children) {
        $!root-node = Terminal::Widgets::RichTreeViewNode.new;
        self!refresh-dn;
    }

    method !nodes-to-dns(@nodes, $parent, $depth) {
        my @lines;
        my @dns = @nodes.kv.map: -> $index, $node {
            my $expanded = self!prop-for-node($node).expanded;
            @lines.push: &!get-node-prefix($depth, $expanded, $node.leaf, $index == @nodes.end) ~ $node.text;
            my @children;
            if $expanded {
                my @res = self!nodes-to-dns(&!get-children($node.id), Nil, $depth + 1);
                @children := @res[0];
                my @child-lines := @res[1];
                @lines.append: @child-lines;
            }
            DisplayNode.new(
                :$node,
                :@children,
                :$depth,
                :$parent,
            )
        }
        @dns, @lines
    }

    method !refresh-dn() {
        my (@dns, @lines) := self!nodes-to-dns(&!get-children(Nil), Nil, 0);
        # Ensure @lines is one line per entry.
        @lines .= map(*.lines.join);
        self!set-text(@lines.join("\n"));
        $!dn-root = DisplayNode.new(
            :children(@dns),
            :depth(0),
        );
    }

    method !prop-for-node($node) {
        for @!node-props -> $prop {
            return $prop if $prop.id eqv $node.id-for-props;
        }
        my $prop = NodeProperties.new(
                id => $node.id-for-props,
            );
        @!node-props.push: $prop;
        $prop
    }

    method !line-to-dn($line-no) {
        sub line-to-dn-rec($pos is rw, $line, $dn) {
            return $dn if $pos == $line;
            for $dn.children -> $child {
                $pos++;
                return $_ with line-to-dn-rec($pos, $line, $child);
            }
        }

        # First child of the root is at pos 0, so the root is at pos -1. 
        my $cur-line = -1;
        line-to-dn-rec($cur-line, $line-no, $!dn-root)
    }

    method !expand-node() {
        my $line = $!cursor-y;
        my $dn = self!line-to-dn($line);
        my $prop = self!prop-for-node($dn.node);
        if !$prop.expanded {
            self!prop-for-node($dn.node).expanded = True;
            my @children = &!get-children($dn.node.id);
            if @children {
                my (@dns, @lines) := self!nodes-to-dns(@children, $dn, $dn.depth + 1);
                $dn.children = @dns;
                self!splice-lines($line+1, 0, @lines.join("\n"));
            }
        }
    }

    method !collapse-node() {
        my $line = $!cursor-y;
        my $dn = self!line-to-dn($line);
        self!prop-for-node($dn.node).expanded = False;
        self!splice-lines($line+1, $dn.child-line-count, ());
        $dn.children = ();
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'select-next-line',
            CursorUp    => 'select-prev-line',
            CursorRight => 'expand-node',
            CursorLeft  => 'collapse-node',
            Ctrl-I      => 'next-input',    # Tab
            ShiftTab    => 'prev-input',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next-line' { self!select-line($!cursor-y + 1) }
            when 'select-prev-line' { self!select-line($!cursor-y - 1) }
            when 'expand-node'      { self!expand-node }
            when 'collapse-node'    { self!collapse-node }
            when 'next-input'       { self.focus-next-input }
            when 'prev-input'       { self.focus-prev-input }
        }
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        self.toplevel.focus-on(self);

        my ($x, $y) = $event.relative-to(self);
        my $clicked-display-line = $!first-display-line + $y;
        my $line-index = @!dl-l[min($clicked-display-line, @!dl-l.end)];
        $!cursor-y = $line-index;
        my $rel-y = $y - @!l-dl[$line-index];
        $x = self!display-pos-to-line-pos(@!lines[$line-index], self.x-scroll + $x, $rel-y);
        $!cursor-x = min(self!chars-in-line(@!lines[$line-index]) - 1, $x);
        self.full-refresh;
        &!process-click($line-index, $x, 0) with &!process-click;
    }

    sub log($t) {
        "o".IO.spurt: $t ~ "\n", :append;
    }
}
