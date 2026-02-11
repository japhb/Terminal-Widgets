# ABSTRACT: A top-level (full-screen) widget

use nano;

use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;
use Terminal::Widgets::Widget;


#| A top-level full-screen widget with modal access to its controlling terminal
role Terminal::Widgets::TopLevel
  is Terminal::Widgets::Widget {
    has         $.terminal is required;
    has Str     $.title;
    has Array:D %.named-group;

    has Terminal::Widgets::Widget:D %.by-id;
    has Terminal::Widgets::Widget   $.focused-widget;


    ### Required overrides

    #| Lay out and build main subwidgets (and dividers/frames, if any)
    method build-layout() { ... }


    ### Core implementation

    #| Hook start/end of event processing to provide debug info
    method process-event(Terminal::Widgets::Events::Event:D $event,
                         Terminal::Widgets::Events::EventPhase:D $phase = TrickleDown) {
        my $show-time = $.debug && $phase == TrickleDown;
        note '⚙️  Processing ' ~ $event.gist if $show-time;
        my $t0 = nano;

        callsame;

        if $show-time {
            self.debug-elapsed($t0, desc => 'Event #' ~ $event.id ~ ' processed');
            note '' unless $event ~~ Terminal::Widgets::Events::TakeFocus;
        }
    }

    #| Throw an exception if a widget with a given id is already known
    method !ensure-new-id($id) {
        die 'This ' ~ self.gist-name ~ ' already contains a widget with id ' ~ $id.raku
            if %!by-id{$id}:exists;
    }

    #| Cache the id for a particular widget, erroring if duplicated
    method cache-widget-id($widget) {
        if $widget.id -> $id {
            self!ensure-new-id($id);
            %!by-id{$id} = $widget;
        }
    }

    #| Add a widget to a named group
    method add-to-group(Terminal::Widgets::Widget:D $widget, Str:D $group) {
        %!named-group{$group}.push($widget);
    }

    #| Remove a widget from a named group
    method remove-from-group(Terminal::Widgets::Widget:D $widget, Str:D $group) {
        %!named-group{$group} .= grep(* !=== $widget);
    }

    #| All members of a given named group
    method group-members(Str:D $group) {
        %!named-group{$group} // Empty
    }

    #| Check if the Terminal believes this is its current TopLevel
    method is-current-toplevel(--> Bool:D) {
        self === $.terminal.current-toplevel
    }

    #| Send an event requesting that a target widget takes focus,
    #| and do necessary unfocus/refocus redraws
    method focus-on(Terminal::Widgets::Widget:D $target,
                    Bool:D :$redraw = True) {
        note "⚙️  Processing top level focus-on for: {$target.gist-name}" if $.debug;
        my $t0 = nano;

        # Determine if focus is *really* changing
        my $prev    = $!focused-widget;
        my $changed = $prev && $prev !=== $target;

        # Redraw previous widget as unfocused
        if $redraw && $changed {
            $!focused-widget = Nil;
            $prev.full-refresh;
        }

        # Actually send the TakeFocus event (sends even if !$changed because
        # this could have been triggered by a reparenting operation, so the
        # widget tree needs focused-child fixups)
        self.process-event(Terminal::Widgets::Events::TakeFocus.new(:$target));
        $!focused-widget = $target;

        # Draw target widget as focused
        $target.full-refresh if $redraw;

        self.debug-elapsed($t0, desc => 'focus-on processed for ' ~ $target.gist-name);
    }

    #| Redraw entire widget tree
    method redraw-all() {
        note "🆕 Starting redraw-all of: {self.gist-name}" if $.debug;
        my $t0 = nano;

        my $frame-info = Terminal::Widgets::FrameInfo.new;
        self.do-frame($frame-info);

        self.debug-elapsed($t0);
    }

    #| Relayout, redraw, and composite entire widget tree
    method relayout(Bool:D :$focus = False) {
        note '⚙️  Processing top level relayout request' if $.debug;
        my $t0 = nano;

        # Build the layout and then send a global event that layout has completed
        self.build-layout;
        self.process-event(Terminal::Widgets::Events::LayoutBuilt.new);

        # Set focus if needed, redraw the entire widget tree, and composite the TopLevel
        self.gain-focus(:!redraw) if $focus;
        self.redraw-all;
        self.composite;

        self.debug-elapsed($t0);
    }

    # XXXX: Allow terminal to be disconnected or switched?
    # XXXX: Does disconnect imply recursive destroy?
}
