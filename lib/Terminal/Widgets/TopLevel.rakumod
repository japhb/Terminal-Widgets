# ABSTRACT: A top-level (full-screen) widget

use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;
use Terminal::Widgets::Widget;


#| A top-level full-screen widget with modal access to its controlling terminal
role Terminal::Widgets::TopLevel
  is Terminal::Widgets::Widget
does Terminal::Widgets::Layout::WidgetBuilding {
    has         $.terminal is required;
    has Str     $.title;
    has Array:D %.named-group;

    has Terminal::Widgets::Widget $.focused-widget;


    ### Required overrides

    #| Lay out main subwidgets (and dividers/frames, if any)
    method build-layout() { ... }


    ### Core implementation

    #| Hook start/end of event processing to provide debug info
    method process-event(Terminal::Widgets::Events::Event:D $event,
                         Terminal::Widgets::Events::EventPhase:D $phase = TrickleDown) {
        my $show-time = $.debug && $phase == TrickleDown;
        note '⚙️  Processing ' ~ $event.gist if $show-time;
        my $t0 = now;

        callsame;

        note sprintf("⏱️  Event #%d processed: %.3fms\n",
                     $event.id, 1000 * (now - $t0)) if $show-time;
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
    }

    #| Redraw entire widget tree
    method redraw-all() {
        my $frame-info = Terminal::Widgets::FrameInfo.new;
        self.do-frame($frame-info);
    }

    #| Relayout, redraw, and composite entire widget tree
    method relayout(Bool:D :$focus = False) {
        # Build the layout and then send a global event that layout has completed
        self.build-layout;
        self.process-event(Terminal::Widgets::Events::LayoutBuilt.new);

        # Set focus if needed, redraw the entire widget tree, and composite the TopLevel
        self.gain-focus(:!redraw) if $focus;
        self.redraw-all;
        self.composite;
    }

    # XXXX: Allow terminal to be disconnected or switched?
    # XXXX: Does disconnect imply recursive destroy?
}
