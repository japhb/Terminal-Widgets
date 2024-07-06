# ABSTRACT: A text widget that has clickable lines / a selected line.

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;

role Terminal::Widgets::TreeViewNode {
    #| A single line of text for this node.
    has Str $.text;
}

role Terminal::Widgets::ShallowTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| Some identifier. Can be any object.
    has $.id;

    #| Optional. If set to True, the node will hide the "expand" marker
    #| of the node, even if it wasn't opened yet.
    has Bool $.leaf = False;
}

role Terminal::Widgets::RichTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| Optional. Providing an ID for each node will allow saving and restoring
    #| the state of each node more reliably in the case of a changing tree
    #| structure.
    has $.id;

    #| This nodes children. If empty, it's a leaf node.
    has Terminal::Widgets::RichTreeViewNode @.children;
}

class Terminal::Widgets::TreeView
 does Terminal::Widgets::SpanWrappingAndHighlighting
 does Terminal::Widgets::Focusable {
    my class NodeProperties {
        has $.id;
        has Bool $.expanded;
    }

    my class DisplayNode {
        has Terminal::Widgets::TreeViewNode $.node;
        has DisplayNode @.children;

        method line-count() {
            1 + [+] @!children.map: *.line-count
        }
    }

    my class WrappedRichNode
      does Terminal::Widgets::ShallowTreeViewNode {
        has Terminal::Widgets::RichTreeViewNode $.orig;
    }

    sub line-to-node($pos is rw, $line, @nodes) {
        for @nodes -> $n {
            return $n if $pos == $line;
            $pos++;
            return $_ with line-to-node($pos, $line, $n.children);
        }
    }

    #| A function that will, when given a node ID, will return a list of that
    #| nodes children. When passed Nil as the node ID, it must return the top
    #| level nodes.
    #| sub get-children($node-id --> List[ShallowTreeViewNodes])
    has &.get-children;

    #| Alternatively to &.get-children, one can just pass a complete
    #| RichTreeViewNode list.
    has RichTreeViewNode @.tree;

    #| DisplayNode trees. Contains a list of all visible nodes. Not necessarily
    #| on the screen, but not hidden in a collapsed parent.
    has @!dn-trees;

    #| Node 
    has NodeProperties @.node-props;

    has &.process-click;

    submethod TWEAK(:$wrap, :$tree = Any, $get-children = Any) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;

        self.init-focusable;

        die '@tree XOR &get-children is required' unless $tree.defined ^^ $get-children.defined;

        if $tree.defined {
            @!tree = @$tree;
            &!get-children = sub ($id) {
                get-children-of-tree(@!tree, $id)        
            }
        }

        self!refresh-dn;
    }

    sub get-children-of-tree(@tree, $id) {
        # In a wrapped tree, we'll populate the ID with a list of indexes
        # leading to the node.
        my @l := @tree;
        my @ids;
        if ! $id === Nil {
            for @$id -> $index {
                @l := @l[$index];
            }
            @ids = @$id;
        }
        @l.kv.map: -> $i, $node {
            Terminal::Widgets::WrappedRichNode.new:
                id => (|@ids, $i),
                orig => $node,
                leaf => $node.children.elems == 0,
                text => $node.text,
            ;
        }
    }

    method !nodes-to-dns($splice-at, @nodes) {
        @nodes.map: -> $node {
            self!splice-lines($splice-at, 0, $node.text);
            my @children;
            if my $prop = self!prop-for-id($node.id) && $prop.expanded {
                @children = self!nodes-to-dns($first-line+1, $node.children);
            }
            DisplayNode.new(
                :$node,
                :@children,
            );
        }
    }

    method !refresh-dn() {
        @!dn-trees = ();
        self!set-text('');
        @!dn-trees = self!nodes-to-dns(0, &!get-children(Nil));
    }

    method !prop-for-id($id) {
        for @!node-props -> $prop {
            return $prop if $prop.id eqv $id;
        }
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'select-next-line',
            CursorUp    => 'select-prev-line',
            CursorLeft  => 'select-prev-char',
            CursorRight => 'select-next-char',
            Ctrl-I      => 'next-input',    # Tab
            ShiftTab    => 'prev-input',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next-line' { self!select-line($!cursor-y + 1) }
            when 'select-prev-line' { self!select-line($!cursor-y - 1) }
            when 'select-next-char' { self!next-char }
            when 'select-prev-char' { self!prev-char }
            when 'next-input'  { self.focus-next-input }
            when 'prev-input'  { self.focus-prev-input }
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
