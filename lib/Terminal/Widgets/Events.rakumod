# ABSTRACT: Basic event handling system with trickle/bubble semantics

unit module Terminal::Widgets::Events;

use Terminal::LineEditor::RawTerminalInput;


#| Phases of event processing
enum EventPhase is export < TrickleDown AtTarget BubbleUp >;


# Unique ID generator for events
my atomicint $NEXT-ID = 0;
sub term:<NEXT-ID>() { ++⚛$NEXT-ID }

#| A basic generic event class
class Event {
    has $.id      = NEXT-ID;
    has $.created = now;
    has %.bubbled-up-to is SetHash;

    method gist() {
        my $name = self.^name.subst('Terminal::Widgets::', '');
        my $time = $!created - $*INIT-INSTANT;

        $name ~ ' #' ~ $!id ~ ', created:' ~ $time.round(.001)
    }
}


#| A global event that reaches all leaves
class GlobalEvent is Event { }


#| A global event indicating a TopLevel's widget tree has been laid out fully
class LayoutBuilt is GlobalEvent { }


#| An event that follows the focus path
class FocusFollowingEvent is Event { }


#| Keyboard events
class KeyboardEvent is FocusFollowingEvent {
    has $.key is required;

    #| Return a keyname string suitable for looking up in keymaps
    method keyname() {
        do given $.key {
            when Str {
                my $ord = .ord;
                $ord <  32  ?? 'Ctrl-' ~ ($ord + 64).chr !!
                $ord == 127 ?? 'Backspace' !!
                               $_
            }
            when Pair {
                my $key = .key;
                $key ~~ Str        ??  $key !!
                $key ~~ SpecialKey ?? ~$key !!
                                        ('Meta-'  if $key.meta)
                                      ~ ('Ctrl-'  if $key.control)
                                      ~ ('Alt-'   if $key.alt)
                                      ~ ('Shift-' if $key.shift)
                                      ~ $key.key
            }
        }
    }

    method gist() {
        callsame() ~ ', key:' ~ self.keyname
    }
}


#| A targeted event
class TargetedEvent is Event {
    has $.target is required;

    method gist() {
        callsame() ~ ', target:' ~ $!target.gist
    }
}


#| Take focus from target through root
class TakeFocus is TargetedEvent { }


#| An event that occurs at a particular screen location
class LocalizedEvent is Event {
    # Calculations relative to widget as a whole
    method overlaps-widget($widget --> Bool:D)       { ... }
    method relative-to($widget)                      { ... }

    # Calculations relative to widget's content area
    method overlaps-content-area($widget --> Bool:D) { ... }
    method relative-to-content-area($widget)         { ... }
}


#| Mouse events
class MouseEvent is LocalizedEvent {
    has $.mouse is required;

    #| Determine whether this mouse event overlapped a particular widget
    method overlaps-widget($widget --> Bool:D) {
        my $rel-x = $.mouse.x - 1 - $widget.x-offset;
        my $rel-y = $.mouse.y - 1 - $widget.y-offset;

        0 <= $rel-x < $widget.w && 0 <= $rel-y < $widget.h
    }

    #| Compute coordinates relative to a given widget's local origin
    method relative-to($widget) {
        my $rel-x = $.mouse.x - 1 - $widget.x-offset;
        my $rel-y = $.mouse.y - 1 - $widget.y-offset;

        ($rel-x, $rel-y, $widget.w, $widget.h)
    }

    #| Determine whether this mouse event overlapped a particular widget
    method overlaps-content-area($widget --> Bool:D) {
        my $rect  = $widget.content-rect;
        my $rel-x = $.mouse.x - 1 - $widget.x-offset - $rect[0];
        my $rel-y = $.mouse.y - 1 - $widget.y-offset - $rect[1];

        0 <= $rel-x < $rect[2] && 0 <= $rel-y < $rect[3]
    }

    #| Compute coordinates relative to a given widget's local origin
    method relative-to-content-area($widget) {
        my $rect  = $widget.content-rect;
        my $rel-x = $.mouse.x - 1 - $widget.x-offset - $rect[0];
        my $rel-y = $.mouse.y - 1 - $widget.y-offset - $rect[1];

        ($rel-x, $rel-y, $rect[2], $rect[3])
    }

    method gist() {
        my $button-mods  = ('Meta-'   if $!mouse.meta)
                         ~ ('Ctrl-'   if $!mouse.control)
                         ~ ('Shift-'  if $!mouse.shift)
                         ~ ('Motion-' if $!mouse.motion)
                         ~ ($!mouse.pressed ?? 'Pressed-' !! 'Released-')
                         ~ ('Button' ~ $!mouse.button);
        my $mouse-gist = '@' ~ $!mouse.x ~ ',' ~ $!mouse.y ~ ':' ~ $button-mods;

        callsame() ~ ', mouse:' ~ $mouse-gist
    }
}


#| Event handling interface with trickle-down and bubble-up phases and focus handling
role EventHandling {
    has $.focused-child is rw;  #= For events that follow focus; if undefined, event stops trickling


    ### MUST BE PROVIDED BY CONSUMING CLASS (or one of its roles)

    #| Link to parent, used when bubbling events upward, or undefined if top level
    method parent() { ... }

    #| List of children, used when trickling events downward, or Empty if leaf
    method children() { ... }


    ### ADD MULTIS IN CONSUMING CLASSES TO HANDLE OTHER EVENTS

    #| Ignore otherwise unhandled events
    multi method handle-event(Event:D $event, EventPhase:D $phase) { }

    #| Handle TakeFocus events by setting parent's focused-child and bubbling up
    multi method handle-event(TakeFocus:D $event, EventPhase:D $phase) {
        if $phase != TrickleDown {
            $.parent.focused-child = self if $.parent;
            self.focused-child = Nil if $event.target === self;
        }
    }


    ### DEFAULT IMPLEMENTATIONS

    #| Children that understand EventHandling
    method event-handling-children() {
        @.children.grep({ $_ ~~ EventHandling })
    }

    #| Process an event, calling pre- and post- hooks
    method process-event(Event:D $event, EventPhase:D $phase = TrickleDown) {
        # Drop if pre-process-event returns undefined event object
        my $processed = self.pre-process-event($event, $phase);
        return unless my $e = $processed[0];

        # Otherwise, handle event normally and post-process to continue
        self.handle-event($e, $processed[1]);
        self.post-process-event($e, $processed[1]);
    }

    #| Pre-process an event, allowing replacement event and/or phase
    method pre-process-event(Event:D $event, EventPhase:D $phase) {
        if $event ~~ TargetedEvent {
            # Search for target during TrickleDown phase
            my $at-target = $phase == TrickleDown && $event.target === self;

            $at-target ?? ($event, AtTarget) !!  # Found the target, new phase
            @.event-handling-children
                       ?? ($event, $phase)   !!  # Has children, keep searching
                          (Nil,    BubbleUp)     # Target was not on this branch
        }
        elsif $event ~~ FocusFollowingEvent {
            # Stop trickling down if no child has focus
            my $at-target = $phase == TrickleDown && !$.focused-child;
            $at-target ?? ($event, AtTarget) !! ($event, $phase)
        }
        else {
            # Consider leaves to be the 'target' for untargeted events
            @.event-handling-children ?? ($event, $phase) !! ($event, AtTarget)
        }
    }

    #| Post-process an event, by trickling down or bubbling up as appropriate
    method post-process-event(Event:D $event, EventPhase:D $phase) {
        $phase == TrickleDown ?? self.trickle-down($event)
                              !! self.bubble-up($event);
    }

    #| Trickle an event down to the children (or focused-child if FocusFollowingEvent)
    method trickle-down(Event:D $event) {
        # Send to focused-child if the event so requests
        if $event ~~ FocusFollowingEvent {
            .process-event($event, TrickleDown) with $.focused-child;
        }
        # Or send to overlapping children at nearest Z level if localized
        elsif $event ~~ LocalizedEvent {
            my @overlapped
                = @.event-handling-children.grep({ $event.overlaps-widget($_) });
            # XXXX: Use .z-offset instead?
            # XXXX: Optimize special case when @overlapped == 1?
            my $max-z = @overlapped.map(*.z).max;
            my @top   = @overlapped.grep(*.z == $max-z);
            .process-event($event, TrickleDown) for @top;
        }
        # Else just send to all children that can understand events
        else {
            .process-event($event, TrickleDown) for @.event-handling-children;
        }
    }

    #| Bubble an event up to the parent, if any
    method bubble-up(Event:D $event) {
        $.parent.process-event($event, BubbleUp)
            if $.parent && !$event.bubbled-up-to{$.parent}++;
    }
}
