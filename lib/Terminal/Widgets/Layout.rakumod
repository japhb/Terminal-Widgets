# ABSTRACT: Widget layout using a simplified box model

unit module Terminal::Widgets::Layout;

use Terminal::Widgets::Common;
use Terminal::Widgets::WidgetRegistry;
use Terminal::Widgets::Layout::BoxModel;


#| General exception class for layout failures
class X::CannotLayout is Exception { }

#| X::CannotLayout subclass for extra space needed
class X::CannotLayout::TooSmall is X::CannotLayout {
    has UInt   $.min-w is required;
    has UInt   $.set-w is required;
    has UInt   $.max-w is required;

    has UInt   $.min-h is required;
    has UInt   $.set-h is required;
    has UInt   $.max-h is required;

    has UInt:D $.need-w = self!need($!min-w // 0, $!set-w // 0, $!max-w // 0);
    has UInt:D $.need-h = self!need($!min-h // 0, $!set-h // 0, $!max-h // 0);

    method !need(UInt:D $min, UInt:D $set, UInt:D $max) {
        my $max-nx = $min max $max;
        my $min-nx = $min min $max;

        $set >  $max-nx      ?? $set - $max !!
        $set <  $min-nx      ?? $min - $set !!
        $max <  $min         ?? $min - $max !! 0
    }

    method message() {
        my $need = (("+$.need-w width"  if $.need-w),
                    ("+$.need-h height" if $.need-h)).join(' and ');

        "Cannot layout because available space is too small; need $need"
    }
}

#| X::CannotLayout subclass for conflicting parent/child sets
class X::CannotLayout::SetMismatch is X::CannotLayout {
    has UInt:D $.parent-w   is required;
    has UInt:D $.parent-h   is required;
    has UInt:D $.children-w is required;
    has UInt:D $.children-h is required;

    has UInt:D $.need-w = ($!parent-w - $!children-w).abs;
    has UInt:D $.need-h = ($!parent-h - $!children-h).abs;

    method message() {
        "Cannot layout because computed parent node size (w: $.parent-w, h: $.parent-h) does not match computed children size (w: $.children-w, h: $.children-h)"
    }
}

#| X::CannotLayout subclass for combining multiple child failures
class X::CannotLayout::ChildFailures is X::CannotLayout {
    has @.failures is required;

    has UInt:D $.need-w = @!failures.map(*.need-w).sum;
    has UInt:D $.need-h = @!failures.map(*.need-h).sum;

    method message() {
        my $need = (("+$.need-w width"  if $.need-w),
                    ("+$.need-h height" if $.need-h)).join(' and ');

        "Cannot layout because child nodes failed to do so; need $need"
    }
}

#| Style information (either requested or computed) for a layout node/leaf
class Style
 does Terminal::Widgets::Layout::BoxModel::BoxModel {
    # NOTE: Since Style is immutable we can assume that once instantiated, if
    #       set-* is defined, then min-* and max-* must be as well; likewise,
    #       if min-* and max-* are both defined and the same, then set-* is
    #       defined and the same.

    has UInt $.set-w;
    has UInt $.set-h;
    has UInt $.min-w;
    has UInt $.min-h;
    has UInt $.max-w;
    has UInt $.max-h;
    has Bool $.minimize-w;
    has Bool $.minimize-h;
    has UInt:D $.share-w = 1;
    has UInt:D $.share-h = 1;

    # Force clone to call TWEAK (just like bless/new) and pass TWEAK Failures through
    method clone {
        my $clone  = callsame;
        my $result = $clone.Style::TWEAK;

        $result ~~ Failure ?? $result !! $clone
    }

    submethod TWEAK() {
        self.Terminal::Widgets::Layout::BoxModel::BoxModel::TWEAK;

        $!min-w //= $!set-w;
        $!max-w //= $!set-w;
        $!min-h //= $!set-h;
        $!max-h //= $!set-h;
        $!set-w //= $!min-w if $!min-w.defined && $!max-w.defined && $!min-w == $!max-w;
        $!set-h //= $!min-h if $!min-h.defined && $!max-h.defined && $!min-h == $!max-h;

        # Prevent non-sensical styles
        fail X::CannotLayout::TooSmall.new(:$!min-w, :$!set-w, :$!max-w,
                                           :$!min-h, :$!set-h, :$!max-h)
            if ($!min-w.defined && $!max-w.defined && $!min-w > $!max-w)
            || ($!min-h.defined && $!max-h.defined && $!min-h > $!max-h)
            || ($!set-w.defined && $!min-w.defined && $!min-w > $!set-w)
            || ($!set-w.defined && $!max-w.defined && $!max-w < $!set-w)
            || ($!set-h.defined && $!min-h.defined && $!min-h > $!set-h)
            || ($!set-h.defined && $!max-h.defined && $!max-h < $!set-h);
    }

    multi method gist(Style:D:) {
        my $padding = $.has-padding ?? ($.pt, $.pr, $.pb, $.pl).join(',') !! 0;
        my $border  = $.has-border  ?? ($.bt, $.br, $.bb, $.bl).join(',') !! 0;
        my $margin  = $.has-margin  ?? ($.mt, $.mr, $.mb, $.ml).join(',') !! 0;
        my $wc      = $.width-correction;
        my $hc      = $.height-correction;
        my $lc      = $.left-correction;
        my $rc      = $.right-correction;
        my $tc      = $.top-correction;
        my $bc      = $.bottom-correction;

        'w:(' ~ ($.min-w, $.set-w, $.max-w).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-w) ~ ') ' ~
        'h:(' ~ ($.min-h, $.set-h, $.max-h).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-h) ~ ')'
         ~ (' ' ~ $.sizing-box ~ ' p:' ~ $padding ~ ' b:' ~ $border ~
            ' m:' ~ $margin ~ ' wc:' ~ $wc ~ '=' ~ $lc ~ '+' ~ $rc ~
            ' hc:' ~ $hc ~ '=' ~ $tc ~ '+' ~ $bc
            if $.has-framing)
    }

    multi method gist(Style:U:) {
        'Style:U'
    }
}


#| Role for dynamic layout nodes, tracking both requested and computed styles
role Dynamic
does Terminal::Widgets::Common {
    has         %.extra;
    has Style   $.requested;
    has Style   $.computed is rw;
    has Dynamic $.parent   is rw;
    has         $.widget   is rw;
    has UInt    $.x        is rw;
    has UInt    $.y        is rw;

    method compute-layout() { ... }
    method propagate-xy()   { ... }

    method default-styles() { hash() }

    method update-requested(*%updates) {
        self.uncompute;
        my $clone   =  $!requested.clone(|%updates);
        fail $clone if $clone ~~ Failure;
        $!requested =  $clone;
    }

    method uncompute() {
        $!computed = Nil;
    }

    method is-set() {
        $.computed && $.computed.set-w.defined && $.computed.set-h.defined
        && $.x.defined && $.y.defined
    }

    method initial-compute() {
        # Start with previously computed styles if available, or requested styles if not
        my $style = $.computed // $.requested;
        my $min-w = $style.min-w;
        my $set-w = $style.set-w;
        my $max-w = $style.max-w;
        my $min-h = $style.min-h;
        my $set-h = $style.set-h;
        my $max-h = $style.max-h;

        if $.parent {
            # Try to pull settings from parent, correcting for box layers --
            # this widget's MarginBox needs to fit in the parent's ContentBox
            my $pc = $.parent.computed;
            if $.parent.vertical {
                my $correction =    $pc.width-correction(ContentBox)
                               + $style.width-correction(MarginBox);
                my $pc-smw     = $pc.set-w // $pc.max-w;

                $min-w //= 0 max $pc.min-w - $correction if $pc.min-w.defined;
                $set-w //= 0 max $pc.set-w - $correction if $pc.set-w.defined;
                $max-w //= 0 max $pc-smw   - $correction if $pc-smw.defined;
            }
            else {
                my $correction =    $pc.height-correction(ContentBox)
                               + $style.height-correction(MarginBox);
                my $pc-smh     = $pc.set-h // $pc.max-h;

                $min-h //= 0 max $pc.min-h - $correction if $pc.min-h.defined;
                $set-h //= 0 max $pc.set-h - $correction if $pc.set-h.defined;
                $max-h //= 0 max $pc-smh   - $correction if $pc-smh.defined;
            }
        }
        else {
            # Try to set values directly
            $set-w //= $max-w // $min-w;
            $set-h //= $max-h // $min-h;
        }

        # Default minimums to 0
        $min-w //= 0;
        $min-h //= 0;

        ($style.clone(:$min-w, :$set-w, :$max-w, :$min-h, :$set-h, :$max-h),
         $min-w, $set-w, $max-w,
         $min-h, $set-h, $max-h)
    }
}


#| A leaf node in the layout tree (no possible children)
class Leaf does Dynamic {
    method builder-name() { 'leaf' }

    multi method gist(Leaf:U:) {
        self.gist-name ~ ':U'
    }

    multi method gist(Leaf:D:) {
        self.gist-name ~ '|' ~
        'requested: [' ~ $.requested.gist ~ '] ' ~
        'computed: ['  ~ $.computed.gist  ~ '] ' ~
        'x:' ~ ($.x // '*') ~ ' y:' ~ ($.y // '*') ~
        (' --- [' ~ $.widget.gist ~ ']' if $.widget)
    }

    method all-set(Leaf:D:) { self.is-set }

    multi method compute-layout(Leaf:D:) {
        # Use initial DWIM computations for final computed style
        my $initial   =  self.initial-compute[0];
        fail $initial if $initial ~~ Failure;
        $!computed    =  $initial;

        self
    }

    method propagate-xy() { }
}


#| A general node in the layout tree (optional children, with tracking of
#| whether children are slotted vertically or horizontally)
class Node does Dynamic {
    has $.vertical;
    has @.children;

    submethod TWEAK() {
        .parent = self for @!children;
    }

    method builder-name() { 'node' }

    multi method gist(Node:U:) {
        self.gist-name ~ ':U'
    }

    multi method gist(Node:D:) {
        my @child-gists = @.children.map: *.gist.indent(4);
        self.gist-name ~ '|' ~
        'requested: [' ~ $.requested.gist ~ '] ' ~
        'computed: ['  ~ $.computed.gist  ~ '] ' ~
        'x:' ~ ($.x // '*') ~ ' y:' ~ ($.y // '*') ~
        (' :vertical' if $.vertical) ~
        (' --- [' ~ $.widget.gist ~ ']' if $.widget) ~
        ($?NL ~ @child-gists.join($?NL) if @.children)
    }

    method uncompute() {
        self.Dynamic::uncompute;
        .uncompute for @.children;
    }

    method all-set(Node:D:) {
        self.is-set && all(@.children.map(*.all-set))
    }

    multi method compute-layout(Node:D:) {
        my $debug = $*DEBUG;
        note "Before layout computation:\n" ~ self.gist ~ "\n" if $debug >= 2;

        # Do initial DWIM computations
        my ($style,
            $min-w, $set-w, $max-w,
            $min-h, $set-h, $max-h) = self.initial-compute;

        fail $style if $style ~~ Failure;

        # Assign *partially* computed style to allow children to introspect this node
        $!computed = $style;
        note "Initial compute:\n" ~ self.gist ~ "\n" if $debug >= 2;

        # Skip remainder if no children
        return unless @.children;

        # Compute all children based on partial info so far, aggregating
        # Failures into an X::CannotLayout::ChildFailures if needed
        my @failed-children;
        .compute-layout || @failed-children.push($_) for @.children;
        fail X::CannotLayout::ChildFailures.new(failures => @failed-children)
            if @failed-children;

        note "After children computed:\n" ~ self.gist ~ "\n" if $debug >= 2;

        # Cache box model corrections for our ContentBox
        my $cwc = $!computed.width-correction( ContentBox);
        my $chc = $!computed.height-correction(ContentBox);

        # Incorporate already-known children's settings into current where possible
        my @child-style = @.children.map(*.computed);

        # Minimums: always useful, though calculation varies by orientation
        my @child-min-w = @child-style.map:
                          { (.min-w // 0) + .width-correction( MarginBox) };
        my @child-min-h = @child-style.map:
                          { (.min-h // 0) + .height-correction(MarginBox) };
        my $child-min-w = $.vertical ?? @child-min-w.max !! @child-min-w.sum;
        my $child-min-h = $.vertical ?? @child-min-h.sum !! @child-min-h.max;
        $min-w max= $child-min-w - $cwc;
        $min-h max= $child-min-h - $chc;

        # Maximums: only useful if all non-minimized children have the value defined
        #           for a particular measure *and* that result is >= than the min
        my &child-max-w = $.vertical ?? {.max-w.defined || !.minimize-w} !! { True };
        my @child-max-w = @child-style.grep(&child-max-w).map:
            { .max-w.defined ?? .max-w + .width-correction(MarginBox) !! .max-w };
        unless @child-max-w.grep(!*.defined) {
            my $child-max-w = $.vertical ?? @child-max-w.min !! @child-max-w.sum;
            $max-w min= $child-max-w - $cwc if $child-max-w >= $child-min-w;
        }
        my &child-max-h = $.vertical ?? { True } !! {.max-h.defined || !.minimize-h};
        my @child-max-h = @child-style.grep(&child-max-h).map:
            { .max-h.defined ?? .max-h + .height-correction(MarginBox) !! .max-h };
        unless @child-max-h.grep(!*.defined) {
            my $child-max-h = $.vertical ?? @child-max-h.sum !! @child-max-h.min;
            $max-h min= $child-max-h - $cwc if $child-max-h >= $child-min-h;
        }

        # Check whether min/max are equal (and thus force set to be the same)
        # Note that minimums are always defined by this point (though may be 0)
        my $fail-set = False;
        if $max-w.defined && $min-w == $max-w {
            if $set-w.defined && $set-w != $min-w {
                $fail-set = True;
            }
            else {
                $set-w = $min-w;
            }
        }
        if $max-h.defined && $min-h == $max-h {
            if $set-h.defined && $set-h != $min-h {
                $fail-set = True;
            }
            else {
                $set-h = $min-h;
            }
        }

        # Check for min <= set <= max failures
        fail X::CannotLayout::TooSmall.new(:$min-w, :$set-w, :$max-w,
                                           :$min-h, :$set-h, :$max-h) if $fail-set;

        # Set values: subtract out and see what's left
        my @child-set-w = @child-style.grep(*.set-w.defined).map:
            { .set-w + .width-correction(MarginBox) };
        my $child-set-w = $.vertical
                          ?? (@child-set-w ?? @child-set-w.max !! 0)
                          !!  @child-set-w.sum;
        my $corrected-child-set-w = $child-set-w - $cwc;

        # Error detection variables
        my $fail-mismatch = False;
        my $remain-w      = 0;
        my $remain-h      = 0;

        if @.children == @child-set-w {
            if $set-w.defined && $set-w != $corrected-child-set-w {
                $fail-mismatch = True;
            }
            else {
                $set-w = $corrected-child-set-w;
            }
        }
        elsif $set-w.defined {
            $remain-w = $set-w - $corrected-child-set-w;

            # Need to use @.children instead of @child-style because will need to
            # recompute .computed in the while loop below
            my @unset-w = @.children.grep(!*.computed.set-w.defined)
                                    .sort({-(.computed.min-w +
                                             .computed.width-correction(MarginBox))})
                                    .sort(-?*.computed.minimize-w);
            while @unset-w {
                my $sum    = @unset-w.map(*.computed.share-w).sum;
                my $node   = @unset-w.shift;
                my $before = $node.computed;
                $remain-w -= $before.width-correction(MarginBox);

                my $share  = 0 max floor($remain-w * $before.share-w / $sum);
                $share     = 0              if $before.minimize-w;
                $share  max= $before.min-w  if $before.min-w.defined;
                $share  min= $before.max-w  if $before.max-w.defined;
                $remain-w -= $share;

                # Fix child width, tracking any Failures that occur
                my $cloned = $before.clone(:set-w($share));
                if $cloned ~~ Failure {
                    @failed-children.push($cloned);
                }
                else {
                    $node.computed = $cloned;
                    my $computed = $node.compute-layout;
                    @failed-children.push($computed) if $computed ~~ Failure;
                }
            }
        }
        fail X::CannotLayout::ChildFailures.new(failures => @failed-children)
            if @failed-children;

        my @child-set-h = @child-style.grep(*.set-h.defined).map:
            { .set-h + .height-correction(MarginBox) };
        my $child-set-h = $.vertical   ?? @child-set-h.sum !!
                          @child-set-h ?? @child-set-h.max !! 0;
        my $corrected-child-set-h = $child-set-h - $chc;

        if @.children == @child-set-h {
            if $set-h.defined && $set-h != $corrected-child-set-h {
                $fail-mismatch = True;
            }
            else {
                $set-h = $corrected-child-set-h;
            }
        }
        elsif $set-h.defined {
            $remain-h = $set-h - $corrected-child-set-h;

            # Need to use @.children instead of @child-style because will need to
            # recompute .computed in the while loop below
            my @unset-h = @.children.grep(!*.computed.set-h.defined)
                                    .sort({-(.computed.min-h +
                                             .computed.height-correction(MarginBox))})
                                    .sort(-?*.computed.minimize-h);
            while @unset-h {
                my $sum    = @unset-h.map(*.computed.share-h).sum;
                my $node   = @unset-h.shift;
                my $before = $node.computed;
                $remain-h -= $before.height-correction(MarginBox);

                my $share  = 0 max floor($remain-h * $before.share-h / $sum);
                $share     = 0             if $before.minimize-h;
                $share  max= $before.min-h if $before.min-h.defined;
                $share  min= $before.max-h if $before.max-h.defined;
                $remain-h -= $share;

                # Fix child width, tracking any Failures that occur
                my $cloned = $before.clone(:set-h($share));
                if $cloned ~~ Failure {
                    @failed-children.push($cloned);
                }
                else {
                    $node.computed = $cloned;
                    my $computed = $node.compute-layout;
                    @failed-children.push($computed) if $computed ~~ Failure;
                }
            }
        }
        fail X::CannotLayout::ChildFailures.new(failures => @failed-children)
            if @failed-children;

        # Check for additional layout failures
        fail X::CannotLayout::SetMismatch.new(parent-w   => $set-w,
                                              parent-h   => $set-h,
                                              children-w => $corrected-child-set-w,
                                              children-h => $corrected-child-set-h)
            if $fail-mismatch;
        fail X::CannotLayout::TooSmall.new(:$min-w, :$max-w,
                                           :$min-h, :$max-h,
                                           set-w => ($set-w || 0) - (0 min $remain-w),
                                           set-h => ($set-h || 0) - (0 min $remain-w))
            if $remain-w < 0 || $remain-h < 0;

        # Assign final computed style
        $!computed .= clone(:$min-w, :$set-w, :$max-w,
                            :$min-h, :$set-h, :$max-h);

        note "Final layout:\n" ~ self.gist ~ "\n" if $debug >= 2;

        self
    }

    method propagate-xy() {
        # Stop propagating silently if current node has not been placed properly
        return unless $.x.defined && $.y.defined;

        my $x = $.x + $.computed.left-correction;
        my $y = $.y + $.computed.top-correction;

        if $.vertical {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $w = .computed.set-w;
                $x += $w + .computed.width-correction(MarginBox);
            }
        }
    }
}


#| A space consumer around or between layout nodes
class Spacer is Leaf {
    method builder-name() { 'spacer' }
}

#| A visual divider (such as box-drawing lines) between layout nodes
class Divider is Leaf {
    method builder-name() { 'divider' }
}

#| Single line inputs
class SingleLineInput is Leaf {
    method input-class() { ... }

    method default-styles(|c) {
        my $min-w = self.input-class.min-width(|c);
        %( :$min-w, set-h => 1 )
    }
}


#| A widget node; localizes xy coordinate frame for children
#| (upper left of this widget becomes new 0,0 for children)
class Widget is Node {
    method builder-name() { 'widget' }

    method propagate-xy() {
        my $x = $.computed.left-correction;
        my $y = $.computed.top-correction;

        if $.vertical {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $w = .computed.set-w;
                $x += $w + .computed.width-correction(MarginBox);
            }
        }
    }
}


#| A structural node to associate a scrollable child with matched scrollbars
class WithScrollbars is Node {
    method builder-name() { 'with-scrollbars' }
}


# Structural nodes to generate centering node structures

#| A structural node to horizontally center its children
class HCenter is Node {
    method builder-name() { 'hcenter' }
}

#| A structural node to vertically center its children
class VCenter is Node {
    method builder-name() { 'vcenter' }
}

#| A structural node to center its children in both directions
class Center is Node {
    method builder-name() { 'center' }
}


# Structural nodes to push content toward some direction

#| A structural node to push content to the top of the available space
class PushUp is Node {
    method builder-name() { 'push-up' }
}

#| A structural node to push content to the bottom of the available space
class PushDown is Node {
    method builder-name() { 'push-down' }
}

#| A structural node to push content to the left edge of the available space
class PushLeft is Node {
    method builder-name() { 'push-left' }
}

#| A structural node to push content to the right edge of the available space
class PushRight is Node {
    method builder-name() { 'push-right' }
}

#| A structural node to push content to the top left corner of the available space
class PushUpLeft is Node {
    method builder-name() { 'push-up-left' }
}

#| A structural node to push content to the top right corner of the available space
class PushUpRight is Node {
    method builder-name() { 'push-up-right' }
}

#| A structural node to push content to the bottom left corner of the available space
class PushDownLeft is Node {
    method builder-name() { 'push-down-left' }
}

#| A structural node to push content to the bottom right corner of the available space
class PushDownRight is Node {
    method builder-name() { 'push-down-right' }
}


#| Helper class for building style/layout trees
class Builder
 does Terminal::Widgets::WidgetRegistry {
    has $.context is required;

    # Helper to make a new style hash containing only width-related styles
    my sub width-styles(%style) {
        my %w-styles = < min-w set-w max-w minimize-w share-w >.map:
                       { $_ => %style{$_} if %style{$_}:exists }
    }

    # Helper to make a new style hash containing only height-related styles
    my sub height-styles(%style) {
        my %h-styles = < min-h set-h max-h minimize-h share-h >.map:
                       { $_ => %style{$_} if %style{$_}:exists }
    }

    #| Use Widget registry to automatically find builders
    method FALLBACK(Str:D $name, |c) {
        die "Unable to find a layout class for builder method $name.raku()"
            unless self.builder-exists($name);

        my $layout-class = self.layout-for-builder($name);

        $layout-class ~~ Leaf ?? self.build-leaf($layout-class, |c)
                              !! self.build-node($layout-class, |c)
    }

    #| Helper method for building leaf nodes
    method build-leaf($node-type, :%style, *%extra) {
        my $default = $node-type.default-styles(locale => $.context.locale,
                                                :$.context, :%style, |%extra);
        $node-type.new(:$.context, :%extra,
                       requested => Style.new(|$default, |%style))
    }

    #| Helper method for building nodes with optional children
    method build-node($node-type, *@children, :$vertical, :%style, *%extra) {
        my $default = $node-type.default-styles(locale => $.context.locale,
                                                :$.context, :%style, |%extra);
        $node-type.new(:$.context, :@children, :$vertical, :%extra,
                       requested => Style.new(|$default, |%style))
    }

    #| Helper method for associating a scrollable child with matching scrollbars
    method build-with-scrollbars($scrollable, :%style, *%extra) {
        my $scroll-target = $scrollable.extra<id>
            // die "Must specify a string id for a scrollable to add scrollbars";

        with self {
            .build-node(WithScrollbars, :vertical, :%style,
                        .node(
                            $scrollable,
                            .vscroll(:$scroll-target),
                        ),
                        .node(
                            .hscroll(:$scroll-target),
                            .spacer(style => %(set-w => 1, set-h => 1)),
                        )
                       )
        }
    }

    #| Helper method for building horizontal centering layout
    method build-hcenter(*@children, :%style, *%extra) {
        my %outer-style = height-styles(%style);
        with self {
            .build-node(HCenter, style => %outer-style,
                        .spacer(style => %outer-style),
                        .node(|@children, :%style, |%extra),
                        .spacer(style => %outer-style),
                       )
        }
    }

    #| Helper method for building vertical centering layout
    method build-vcenter(*@children, :%style, *%extra) {
        my %outer-style = width-styles(%style);
        with self {
            .build-node(VCenter, :vertical, style => %outer-style,
                        .spacer(style => %outer-style),
                        .node(|@children, :%style, |%extra),
                        .spacer(style => %outer-style),
                       )
        }
    }

    #| Helper method for building fully centering layout
    #| (horizontal outer centering, vertical inner centering)
    method build-center(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(Center,
                        .spacer(style => %( :minimize-h )),
                        .node(:vertical, style => %hstyle,
                              .spacer(style => %( :minimize-w )),
                              .node(|@children, style => %vstyle, |%extra),
                              .spacer(style => %( :minimize-w )),
                             ),
                        .spacer(style => %( :minimize-h )),
                       )
        }
    }

    #| Helper method for building layout that pushes content up
    method build-push-up(*@children, :%style, *%extra) {
        my %outer-style = width-styles(%style);
        with self {
            .build-node(PushUp, :vertical, style => %outer-style,
                        .node(|@children, :%style, |%extra),
                        .spacer(style => %outer-style),
                       )
        }
    }

    #| Helper method for building layout that pushes content down
    method build-push-down(*@children, :%style, *%extra) {
        my %outer-style = width-styles(%style);
        with self {
            .build-node(PushDown, :vertical, style => %outer-style,
                        .spacer(style => %outer-style),
                        .node(|@children, :%style, |%extra),
                       )
        }
    }

    #| Helper method for building layout that pushes content left
    method build-push-left(*@children, :%style, *%extra) {
        my %outer-style = height-styles(%style);
        with self {
            .build-node(PushLeft, style => %outer-style,
                        .node(|@children, :%style, |%extra),
                        .spacer(style => %outer-style),
                       )
        }
    }

    #| Helper method for building layout that pushes content right
    method build-push-right(*@children, :%style, *%extra) {
        my %outer-style = height-styles(%style);
        with self {
            .build-node(PushRight, style => %outer-style,
                        .spacer(style => %outer-style),
                        .node(|@children, :%style, |%extra),
                       )
        }
    }

    #| Helper method for building layout that pushes content up and left
    #| (horizontal outer push, vertical inner push)
    method build-push-up-left(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(PushUpLeft,
                        .node(:vertical, style => %hstyle,
                              .node(|@children, style => %vstyle, |%extra),
                              .spacer,
                             ),
                        .spacer,
                       )
        }
    }

    #| Helper method for building layout that pushes content up and right
    #| (horizontal outer push, vertical inner push)
    method build-push-up-right(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(PushUpRight,
                        .spacer,
                        .node(:vertical, style => %hstyle,
                              .node(|@children, style => %vstyle, |%extra),
                              .spacer,
                             ),
                       )
        }
    }

    #| Helper method for building layout that pushes content down and left
    #| (horizontal outer push, vertical inner push)
    method build-push-down-left(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(PushDownLeft,
                        .node(:vertical, style => %hstyle,
                              .spacer,
                              .node(|@children, style => %vstyle, |%extra),
                             ),
                        .spacer,
                       )
        }
    }

    #| Helper method for building layout that pushes content down and right
    #| (horizontal outer push, vertical inner push)
    method build-push-down-right(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(PushDownRight,
                        .spacer,
                        .node(:vertical, style => %hstyle,
                              .spacer,
                              .node(|@children, style => %vstyle, |%extra),
                             ),
                       )
        }
    }

    # NOTE: If a builder method isn't found below, FALLBACK will try to find
    #       a match in the WidgetRegistry before giving up.

    # Misc leaf nodes (no children ever)
    method leaf(|c)            { self.build-leaf(Leaf,       |c) }
    method spacer(|c)          { self.build-leaf(Spacer,     |c) }
    method divider(|c)         { self.build-leaf(Divider,    |c) }

    # Nodes with optional children
    method node(|c)            { self.build-node(Node,       |c) }

    # Nodes with required children
    method with-scrollbars(|c) { self.build-with-scrollbars( |c) }

    # Centering nodes
    method hcenter(|c)         { self.build-hcenter(         |c) }
    method vcenter(|c)         { self.build-vcenter(         |c) }
    method center(|c)          { self.build-center(          |c) }

    # "Gravitational" (content-pushing) nodes
    method push-up(|c)         { self.build-push-up(         |c) }
    method push-down(|c)       { self.build-push-down(       |c) }
    method push-left(|c)       { self.build-push-left(       |c) }
    method push-right(|c)      { self.build-push-right(      |c) }

    method push-up-left(|c)    { self.build-push-up-left(    |c) }
    method push-up-right(|c)   { self.build-push-up-right(   |c) }
    method push-down-left(|c)  { self.build-push-down-left(  |c) }
    method push-down-right(|c) { self.build-push-down-right( |c) }
}
