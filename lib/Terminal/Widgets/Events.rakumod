# ABSTRACT: Basic event handling system with trickle/bubble semantics

unit module Terminal::Widgets::Events;


#| Phases of event processing
enum EventPhase is export < TrickleDown AtTarget BubbleUp >;


#| A basic generic event class
class Event {
    has $.created = now;
}


#| An event that follows the focus path
class FocusFollowingEvent is Event { }


#| Keyboard events
class KeyboardEvent is FocusFollowingEvent {
    has $.key is required;
}


#| A targeted event
class TargetedEvent is Event {
    has $.target is required;
}


#| Take focus from target through root
class TakeFocus is TargetedEvent { }


#| An event that occurs at a particular screen location
class LocalizedEvent is Event {
    method overlaps-widget($widget --> Bool:D) { ... }
}


#| Mouse events
class MouseEvent is LocalizedEvent {
    has $.mouse is required;

    method overlaps-widget($widget --> Bool:D) {
        my $rel-x = $.mouse.x - 1 - $widget.x-offset;
        my $rel-y = $.mouse.y - 1 - $widget.y-offset;

        0 <= $rel-x < $widget.w && 0 <= $rel-y < $widget.h
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
            @.children ?? ($event, $phase)   !!  # Has children, keep searching
                          (Nil,    BubbleUp)     # Target was not on this branch
        }
        elsif $event ~~ FocusFollowingEvent {
            # Stop trickling down if no child has focus
            my $at-target = $phase == TrickleDown && !$.focused-child;
            $at-target ?? ($event, AtTarget) !! ($event, $phase)
        }
        else {
            # Consider leaves to be the "target" for untargeted events
            @.children ?? ($event, $phase) !! ($event, AtTarget)
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
        # Or send to overlapping children if localized
        elsif $event ~~ LocalizedEvent {
            my @overlapped = @.children.grep({ $event.overlaps-widget($_) });
            .process-event($event, TrickleDown) for @overlapped;
        }
        # Else just send to all children
        else {
            .process-event($event, TrickleDown) for @.children;
        }
    }

    #| Bubble an event up to the parent, if any
    method bubble-up(Event:D $event) {
        $.parent.process-event($event, BubbleUp) if $.parent;
    }
}
