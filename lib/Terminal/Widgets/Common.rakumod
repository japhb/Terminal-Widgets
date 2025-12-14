# ABSTRACT: Role with common methods for all major T-W class hierarchies

use nano;


#| Role with common methods for all major T-W class hierarchies
role Terminal::Widgets::Common {
    #| Cache of DEBUG level at time of object creation
    has UInt:D $.debug = +($*DEBUG // 0);

    #| Shortened name for gists and monikers
    method gist-name() { self.^name.subst('Terminal::Widgets::', '') }

    #| Report an elapsed time when debugging
    method debug-elapsed($start, $end = nano, :$desc is copy, :$icon = '⏱️ ') {
        if $!debug {
            # Find calling routine
            my $caller;
            my $level = 0;
            $caller   = callframe(++$level).code until $caller ~~ Routine;

            # Default description if missing
            $desc   //= $caller.package.^name.subst('Terminal::Widgets::', '')
                      ~ '.' ~ $caller.name;

            # Format rounded elapsed time quickly, without floating point mess
            my $ms    = round(($end - $start) / 1_000_000, .001);
            my $note  = "$icon $desc: $ms" ~ 'ms';

            note $note;
        }
    }
}
