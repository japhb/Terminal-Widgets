# ABSTRACT: Singleton terminal app object

use Terminal::Capabilities;
use Terminal::Capabilities::Autodetect;

use Terminal::Widgets::I18N::Locale;
use Terminal::Widgets::TopLevel;
use Terminal::Widgets::Terminal;


#| A singleton TUI app object, managing Terminal and TopLevel objects
class Terminal::Widgets::App {
    has %!terminal;
    has %!top-level;

    #| Create a new Terminal container for a given named tty, add the new
    #| container to internal data structures, and return it.
    multi method add-terminal(Str:D $moniker,
                              IO::Handle:D :$input,
                              IO::Handle:D :$output,
                              Terminal::Capabilities :$caps is copy,
                              Terminal::Widgets::I18N::Locale :$locale,
                              :%ui-prefs, *%caps) {
        die 'Terminal input and output are not both connected to a valid tty'
            unless $input.t && $output.t;

        # This contortion avoids an error trying to assign to a type object
        for < symbol-set vt100-boxes > {
            %caps{$_}:delete if %caps{$_}:exists and not %caps{$_}.defined;
        }

        # Caller and environment variable overrides
        my $override-symbols = %caps<symbols> || %*ENV<TW_SYMBOLS>;
        %caps<vt100-boxes> //= ?+$_ with %*ENV<TW_VT100_BOXES>;
        %caps<symbol-set>  //= symbol-set($override-symbols)
                                       if $override-symbols;

        if $caps {
            # Already have a Terminal::Capabilities object,
            # but may need to tweak with overrides
            $caps .= clone(|%caps) if %caps;
        }
        else {
            # Don't have a T::C object yet, build a new one
            %caps<symbol-set> //= symbol-set('Full');
            $caps = Terminal::Capabilities.new(|%caps);
        }

        %!terminal{$moniker}
        = Terminal::Widgets::Terminal.new(:$input, :$output, :$caps, :app(self),
                                          |(:%ui-prefs if %ui-prefs),
                                          |(:$locale if $locale));
    }

    #| add-terminal by IO::Path tty object on POSIX
    multi method add-terminal(IO::Path:D $tty, *%config) {
        self.add-terminal:
            $tty.path,
            :input($tty.open(:r)),
            :output($tty.open(:a)),
            |%config
    }

    #| add-terminal by Str tty-name
    multi method add-terminal(Str:D $tty-name, *%config) {
        self.add-terminal($tty-name.IO, |%config);
    }

    #| add-terminal for the current controlling terminal;
    #| on POSIX, this defaults to the special device '/dev/tty'
    multi method add-terminal(*%config) {
        # Env var capabilities autodetection should work for the controlling terminal
        my ($caps, $type, $version) = terminal-env-detect;

        if $*DISTRO.is-win {
            self.add-terminal('controlling', :$caps,
                              :input($*IN), :output($*OUT), |%config)
        }
        else {
            self.add-terminal('/dev/tty'.IO, :$caps, |%config)
        }
    }

    #| Create a new top-level widget of a given class, add it to the known
    #| top-level widgets, and return it.
    method add-top-level(Str:D $moniker,
                         Terminal::Widgets::TopLevel:U :$class,
                         Terminal::Widgets::Terminal:D :$terminal, |c) {
        my $w        = $terminal.w;
        my $h        = $terminal.h;
        my $colorset = $terminal.colorset;

        %!top-level{$moniker} = $class.new(:$terminal, :$colorset,
                                           :$w, :$h, :x(0), :y(0), |c);
    }

    # XXXX: Need to be able to dispose of toplevels as well

    #| Shutdown and remove a terminal by terminal moniker
    multi method remove-terminal(Str:D $moniker) {
        my $terminal = %!terminal{$moniker}:delete
             or die 'Terminal moniker ' ~ $moniker.raku ~ ' not found';

        # XXXX: Disconnect/destroy matching toplevels?

        $terminal.quit;
    }

    #| Shutdown and remove a terminal by terminal object
    multi method remove-terminal(Terminal::Widgets::Terminal:D $terminal) {
        my $moniker = %!terminal.pairs.first(*.value === $terminal).key
            or die 'Terminal object not known to app';
        self.remove-terminal($moniker);
    }
}
