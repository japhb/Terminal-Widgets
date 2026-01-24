# ABSTRACT: Simple horizontal sparkline, generally only one or two lines tall

use Terminal::Capabilities;

use Terminal::Widgets::Layout;
use Terminal::Widgets::Widget;


#| Layout node for a sparkline widget
class Terminal::Widgets::Layout::Sparkline
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'sparkline' }
}


#| Simple horizontal sparkline
class Terminal::Widgets::Viz::Sparkline
is Terminal::Widgets::Widget {
    has @!marks = self.choose-marks;
    has @.data;

    method layout-class() { Terminal::Widgets::Layout::Sparkline }

    #| Choose marks appropriate to terminal capabilities
    method choose-marks($caps = self.terminal.caps) {
        constant @ASCII  = < _ , . - + ^ ' ` >;
        constant @Latin1 = < _ , . - · ° ` ¯ >;
        constant @Uni1   = < ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ >;
        constant @Full   = < ▁ 🭻 🭺 🭹 🭸 🭷 🭶 ▔ >;

        constant %marks  = :@ASCII, :@Latin1, :@Uni1, :@Full;

        $caps.best-symbol-choice(%marks)
    }

    #| Draw the sparkline in the content area
    method draw-content() {
        my ($l, $t, $w, $h) = self.content-rect;

        my $start    = 0 max @!data - $w;
        my @data     = @!data[$start .. *];
        my $min      = @data.min;
        my $max      = @data.max;
        my $range    = $max - $min;
        my $levels   = $h * @!marks;
        my $bottom   = $h - 1;
        my $is-block = @!marks[* - 1] eq '█';

        for @data.kv -> $x, $value {
            my $level = floor .5 + ($levels - 1) * ($value - $min) / $range;
            my $mark  = @!marks[$level % @!marks];
            my $y     = $bottom - ($level div @!marks);

            $.grid.change-cell($x + $l, $y + $t, $mark);
            if $is-block {
                $.grid.change-cell($x + $l, $_ + $t, '█') for ($y + 1) .. $bottom;
            }
        }
    }
}


# Register Viz::Sparkline as a buildable widget type
Terminal::Widgets::Viz::Sparkline.register;
