# ABSTRACT: Simple smoke chart (heatmap with strong time-dependent directionality)

use Terminal::Capabilities;

use Terminal::Widgets::Layout;
use Terminal::Widgets::Widget;


#| Statistics for a single slice of the chart (one pixel-wide column or row)
my role SliceStats {
    # Counts
    has UInt:D $.over   = 0;
    has UInt:D $.under  = 0;
    has UInt:D $.errors = 0;
    has UInt   @.buckets;
}


#| A single slice of the chart (without regard to chart direction)
my class Slice does SliceStats {
    has        $.chart      is required;
    has UInt:D $.pos        is required;
    has UInt:D $.max-bucket is required;
    has Real:D $.val-offset is required;
    has Real:D $.val-scale  is required;

    #| Offset and scale a Real:D value to a bucket
    method bucket-from-real-value(Real:D $value --> Int:D) {
        floor $!val-scale * ($value - $!val-offset)
    }

    #| Add a new observed value and notify chart of appropriate update
    method add-value($value) {
        if $value ~~ Real:D {
            my $bucket = self.bucket-from-real-value($value);
            if $bucket < 0 {
                $!under++;
                $!chart.under-updated(self);
            }
            elsif $bucket > $!max-bucket {
                $!over++;
                $!chart.over-updated(self);
            }
            else {
                @!buckets[$bucket]++;
                $!chart.bucket-updated(self, $bucket);
            }
        }
        else {
            $!errors++;
            $!chart.errors-updated(self);
        }
    }
}


#| A horizontally or vertically sliced chart
my role SlicedChart {
    has UInt:D  $.max-bucket        = 0;
    has UInt:D  $.entries-per-slice = 0;
    has Real:D  $.param-offset      = 0;
    has UInt:D  $.num-slices        = 1;
    has Real:D  $.val-offset        = 0;
    has Real:D  $.val-scale         = 1;
    has Slice   $.cur;

    #| Offset, scale, and wrap a Real:D parameter to a chart slice position
    method pos-from-param(Real:D $param --> UInt:D) {
        (floor($param - $!param-offset) div $!entries-per-slice) % $!num-slices
    }

    #| Add a new entry to the chart, calculating slice from param and bucket from value
    method add-entry($param, $value) {
        my $pos  = self.pos-from-param($param);
        if $pos != $!cur.pos {
            self.finish-cur-slice;
            self.start-slice($pos);
        }
        $!cur.add-value($value);
    }

    #| Finish off the current slice before moving to a new one
    method finish-cur-slice() {
        self.del-marks($!cur);
        self.composite-slice($!cur);
    }

    #| Start a new current slice at a given chart position
    method start-slice(UInt:D $pos) {
        $!cur = Slice.new(:$pos, :$!val-offset, :$!val-scale,
                          :$!max-bucket, chart => self);
        # XXXX: Currently redundant with add-marks, since the latter fills all cells
        # self.clear-slice($!cur);
        self.add-marks($!cur);
        self.composite-slice($!cur);
    }

    ### Required rendering methods

    # Rendering optimizations for large slices, only rendering updated cells
    method bucket-updated(Slice:D $slice, UInt:D $bucket) { ... }
    method errors-updated(Slice:D $slice)  { ... }
    method under-updated( Slice:D $slice)  { ... }
    method over-updated(  Slice:D $slice)  { ... }

    # Full slice rendering methods
    method add-marks(Slice:D $slice)       { ... }
    method del-marks(Slice:D $slice)       { ... }
    method clear-slice(Slice:D $slice)     { ... }
    method composite-slice(Slice:D $slice) { ... }
}


#| Simple smoke chart
#  XXXX: Finish making reorientable
class Terminal::Widgets::Viz::SmokeChart
   is Terminal::Widgets::Widget
 does SlicedChart {
    has @.colormap = self.default-colormap;
    has %!marks    = self.choose-marks;

    # Prevent constant Cell object churn (they're immutable and position-independent)
    has %!mark-cell-cache;
    has %!bucket-cell-cache;

    has $!top;
    has $!left;
    has $!right;
    has $!bottom;

    method layout-class() { Terminal::Widgets::Layout::SmokeChart }

    submethod TWEAK() {
        self.compute-sizing;
        self.start-slice(0);
    }


    #| Choose marks appropriate to terminal capabilities
    method choose-marks($caps = self.terminal.caps) {
        constant %ASCII  =
            top    => 'v',
            center => '.',
            bottom => '^',
            error  => 'X',
            over   => '^',
            under  => 'v';

        constant %Latin1 = |%ASCII,
            center => '·';

        constant %WGL4R  = |%Latin1,
            over   => '▲',
            under  => '▼';

        constant %MES2   = |%WGL4R,
            top    => '∨',
            bottom => '∧';

        constant %Uni1   = |%MES2,
            error  => '╳';

        constant %marks  = :%ASCII, :%Latin1, :%WGL4R, :%MES2, :%Uni1;

        $caps.best-symbol-choice(%marks);
    }

    #| Compute default colormap
    method default-colormap($caps = self.terminal.caps) {
        # Calculate and convert the colormap once
        constant @heatmap-colors =
            (0,0,0), (1,0,0), (2,0,0), (3,0,0), (4,0,0),  # Black to brick red
            (5,0,0), (5,1,0), (5,2,0), (5,3,0), (5,4,0),  # Red to yellow-orange
            (5,5,0), (5,5,1), (5,5,2), (5,5,3), (5,5,4),  # Bright to pale yellow
            (5,5,5);                                      # White

        my @heatmap-dark =
            @heatmap-colors.map: { ~(16 + 36 * .[0] + 6 * .[1] + .[2]) };
    }

    #| Compute sizing details based on layout styling and widget dimensions
    #  XXXX: Must be run on resize!
    method compute-sizing() {
        my $computed = self.layout.computed;
        $!top    = $computed.top-correction;
        $!left   = $computed.left-correction;
        $!right  = self.w - 1 - $computed.right-correction;
        $!bottom = self.h - 1 - $computed.bottom-correction;

        # XXXX: Off-by-one errors here?
        $!max-bucket = 0 max (self.h - $computed.height-correction);
        $!num-slices = 0 max ($!right - $!left + 1);

        $!entries-per-slice ||= @!colormap.elems;
    }

    #| Run a rendering operation for a particular slice while holding the grid lock
    method do-for-slice(Slice:D $slice, &code) {
        my $x = $slice.pos + $!left;
        $.grid.with-grid-lock({ code($.grid.grid, $x) }) if $x <= $!right;
    }

    #| Choose a color from the colormap for a given bucket count
    method color-map(UInt:D $count) {
        # XXXX: Adjust for high entries-per-slice?  Make it optional?
        @!colormap[$count min @!colormap.end]
    }


    ### Rendering optimizations for large slices: only render updated cells

    #| Update widget grid for a single slice bucket being updated
    method bucket-updated(Slice:D $slice, UInt:D $bucket) {
        my $even  = $bucket - $bucket % 2;
        my $y     = $!top max ($!bottom - 1 - $even div 2);
        my $upper = $slice.buckets[$even + 1] // 0;
        my $lower = $slice.buckets[$even]     // 0;
        my $sset  = self.terminal.caps.symbol-set;

        my $cell = do if $sset >= Terminal::Capabilities::WGL4R {
            my $upper-color = self.color-map($upper);
            my $lower-color = self.color-map($lower);
            %!bucket-cell-cache{$upper-color}{$lower-color}
              //= $upper-color eq $lower-color
                   ?? $.grid.cell(' ', 'on_' ~ $upper-color)
                   !! $.grid.cell('▄', $lower-color ~ ' on_' ~ $upper-color)
        }
        else {
            my $color = 'on_' ~ self.color-map($upper max $lower);
            %!mark-cell-cache{' '}{$color}
              //= $.grid.cell(' ', $color)
        }

        self.do-for-slice: $slice, -> $g, $x {
            $.grid.change-cell($x, $y, $cell);
            self.composite-cell($slice, $x, $y);
        }
    }

    #| Update widget grid for a slice's error count being updated
    method errors-updated(Slice:D $slice) {
        my $color = self.color-map($slice.errors);
        my $cell  = %!mark-cell-cache{%!marks<error>}{$color}
                      //= $.grid.cell(%!marks<error>, $color);

        self.do-for-slice: $slice, -> $g, $x {
            $.grid.change-cell($x, $!top, $cell);
            self.composite-cell($slice, $x, $!top);
        }
    }

    #| Update widget grid for a slice's under count being updated
    method under-updated(Slice:D $slice) {
        my $color = self.color-map($slice.under);
        my $cell  = %!mark-cell-cache{%!marks<under>}{$color}
                      //= $.grid.cell(%!marks<under>, $color);

        self.do-for-slice: $slice, -> $g, $x {
            $.grid.change-cell($x, $!bottom, $cell);
            self.composite-cell($slice, $x, $!bottom);
        }
    }

    #| Update widget grid for a slice's over count being updated
    method over-updated(Slice:D $slice) {
        # Errors take precedence, without wasting another screen row
        if !$slice.errors {
            my $color = self.color-map($slice.over);
            my $cell  = %!mark-cell-cache{%!marks<over>}{$color}
                          //= $.grid.cell(%!marks<over>, $color);

            self.do-for-slice: $slice, -> $g, $x {
                $.grid.change-cell($x, $!top, $cell);
                self.composite-cell($slice, $x, $!top);
            }
        }
    }

    #| Composite a single cell to the parent/target-grid
    method composite-cell(Slice:D $slice, $x, $y) {
        self.add-dirty-rect($x, $y, 1, 1);
        self.composite;
    }


    ### Full-slice rendering

    #| Completely clear the grid contents representing a slice
    method clear-slice(Slice:D $slice) {
        self.do-for-slice: $slice, {
            $^g[$_][$^x] = ' ' for $!top .. $!bottom;
        }
    }

    #| Remove any marks still visible in the grid contents for a slice
    #  Assumes data is represented by colored cells, and marks by plain Strs
    method del-marks(Slice:D $slice) {
        self.do-for-slice: $slice, {
            $^g[$_][$^x] = ' ' if $^g[$_][$^x] ~~ Str for $!top .. $!bottom;
        }
    }

    #| Add any desired orienting marks to the grid contents for a slice
    method add-marks(Slice:D $slice) {
        self.do-for-slice: $slice, {
            $^g[$_][$^x]       = %!marks<center> for ($!top + 1) .. ($!bottom - 1);
            $^g[$!top][$^x]    = %!marks<top>;
            $^g[$!bottom][$^x] = %!marks<bottom>;
        }
    }

    #| Composite an entire slice to the parent/target-grid
    method composite-slice(Slice:D $slice) {
        self.add-dirty-rect($slice.pos + $!left,
                            $!top, 1, $!bottom - $!top + 1);
        self.composite;
    }
}


# Register SmokeChart as a buildable widget type
Terminal::Widgets::Viz::SmokeChart.register;
