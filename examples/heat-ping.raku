# ABSTRACT: Heat ping example based on Terminal::Widgets::Viz::SmokeChart

use Terminal::Widgets::Events;
use Terminal::Widgets::Simple;
use Terminal::Widgets::Viz::SmokeChart;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class HeatPingUI is TopLevel {
    has Form:D    $.form .= new;
    has Channel:D $.stop .= new;
    has UInt:D    $.ms-per-pixel   = 2;
    has Str:D     $.default-target = '8.8.8.8';

    method initial-layout($builder, $width, $height) {
        with $builder {
            .text-input(:$.form, id => 'target', :!clear-on-finish,
                        prompt-string => 'Ping Target >'),
            .node(
                .button(:$.form, id => 'start', label => 'Start',
                        process-input  => { self.start-ping }),
                .button(:$.form, id => 'stop',  label => 'Stop', :!enabled,
                        process-input  => { self.stop-ping }),
                .button(:$.form, id => 'clear', label => 'Clear',
                        process-input  => { self.clear-chart }),
                .button(:$.form, id => 'quit',  label => 'Quit',
                        process-input  => { self.stop-ping;
                                            $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .smoke-chart(id => 'chart',
                         val-scale => 1 / ($.ms-per-pixel || 1)),
        }
    }

    method start-ping() {
        # Disable the Start button and enable the Stop button
        %.by-id<start>.set-enabled(False);
        %.by-id<stop>.set-enabled(True);

        # Focus on the chart
        self.focus-on(%.by-id<chart>);

        # Prepare a `ping` child process that the reactor will listen to
        my $target = %.by-id<target>.input-field.buffer.contents
                     || $.default-target;
        my $ping = Proc::Async.new('ping', $target);

        # Update window title to indicate target
        my $title = "$target - heat-ping";
        self.terminal.set-window-title($title);

        # Run ping event reactor until interrupt signal or `ping` exits
        start react {
            # Parse `ping` results
            whenever $ping.stderr.lines { .note }
            whenever $ping.stdout.lines {
                if $_ ~~ / 'seq=' (\d+) .*? 'time=' (\d+ ['.' \d+]?) / -> $/ {
                    self.update-chart(+$0, +$1);
                }
            }

            # Quit on stop requested or child process exit
            whenever $.stop      { done }
            whenever $ping.start { self.stop-ping }
        }
    }

    method stop-ping() {
        # Disable the Stop button and enable the Start button
        %.by-id<stop>.set-enabled(False);
        %.by-id<start>.set-enabled(True);

        # Stop any existing reactor
        $.stop.send('stop');

        # Update window title to indicate ping is now idle
        my $title = "idle - heat-ping";
        self.terminal.set-window-title($title);
    }

    method clear-chart() {
        %.by-id<chart>.clear-frame;
        %.by-id<chart>.start-slice(0);
    }

    method update-chart($id, $time) {
        %.by-id<chart>.add-entry($id, $time);
    }

    # Make a ^C targeting the chart stop the ping reactor
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D $event
                              where *.keyname eq 'Ctrl-C', BubbleUp) {
        self.stop-ping if self.focused-child === %.by-id<chart>;
    }

    # Add an initial value to the Text input when building is complete
    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D $event, BubbleUp) {
        %.by-id<target>.full-refresh($.default-target);
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the UI screen
    App.new.boot-to-screen('heat-ping', HeatPingUI, title => 'Smoke Chart Example');
}
