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
}

role Terminal::Widgets::ShallowTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| Optional. If set to True, the node will hide the "expand" marker
    #| of the node, even if it wasn't opened yet.
    has Bool $.leaf = False;
}

role Terminal::Widgets::RichTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| This nodes children. If empty, it's a leaf node.
    has Terminal::Widgets::RichTreeViewNode @.children;
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
        has DisplayNode @.children is rw;

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
    has Terminal::Widgets::RichTreeViewNode @.trees;

    #| DisplayNode trees. Contains a list of all visible nodes. Not necessarily
    #| on the screen, but not hidden in a collapsed parent.
    has @!dn-trees;

    #| Node 
    has NodeProperties @.node-props;

    has &.process-click;

    submethod TWEAK(:$wrap, :$trees = Any, :$get-children = Any) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;

        self.init-focusable;

        die '@tree and &get-children can not be set both' if $trees.defined && $get-children.defined;

        if !$get-children.defined && !$trees.defined {
            self.set-trees: ();
        }
        if $trees.defined {
            self.set-trees: @$trees;
        }

        self!refresh-dn;
    }

    sub get-children-of-tree(@tree, $id) {
        # In a wrapped tree, we'll populate the ID with a list of indexes
        # leading to the node.
        my @l := @tree;
        my @ids;
        if !($id === Nil) {
            for @$id -> $index {
                @l := @l[$index].children;
            }
            @ids = @$id;
        }
        @l.kv.map: -> $i, $node {
            WrappedRichNode.new:
                id => (|@ids, $i),
                orig => $node,
                leaf => $node.children.elems == 0,
                text => $node.text,
            ;
        }
    }

    method set-trees(@!trees) {
        &!get-children = sub ($id) {
            get-children-of-tree(@!trees, $id);
        }

        self!refresh-dn;
    }

    method set-get-children(&!get-children) {
        @!trees = ();

        self!refresh-dn;
    }

    method !nodes-to-dns(@nodes) {
        my @lines;
        my @dns = @nodes.map: -> $node {
            @lines.push: $node.text;
            my @children;
            if self!prop-for-node($node).expanded {
                my @res = self!nodes-to-dns(&!get-children($node.id));
                @children := @res[0];
                my @child-lines := @res[1];
                @lines.append: @child-lines;
            }
            DisplayNode.new(
                :$node,
                :@children,
            )
        }
        @dns, @lines
    }

    method !refresh-dn() {
        my (@dn-trees, @lines) := self!nodes-to-dns(&!get-children(Nil));
        # Ensure @lines is one line per entry.
        @lines .= map(*.lines.join);
        self!set-text(@lines.join("\n"));
        @!dn-trees = @dn-trees;
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
        sub line-to-dn-rec($pos is rw, $line, @dns) {
            for @dns -> $dn {
                return $dn if $pos == $line;
                $pos++;
                return $_ with line-to-dn-rec($pos, $line, $dn.children);
            }
        }

        my $cur-line = 0;
        line-to-dn-rec($cur-line, $line-no, @!dn-trees)
    }

    method !expand-node() {
        my $line = $!cursor-y;
        my $dn = self!line-to-dn($line);
        my $prop = self!prop-for-node($dn.node);
        if !$prop.expanded {
            self!prop-for-node($dn.node).expanded = True;
            my @children = &!get-children($dn.node.id);
            if @children {
                my (@dn-trees, @lines) := self!nodes-to-dns(@children);
                $dn.children = @dn-trees;
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
