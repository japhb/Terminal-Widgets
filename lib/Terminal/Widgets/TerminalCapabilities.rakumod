# ABSTRACT: Terminal capability and font repertoire data

#| Known symbol sets in superset order
enum SymbolSet < ASCII Latin1 CP1252 W1G WGL4 MES2 Uni1 Uni7 Full >;


#| A container for the available capabilities of a particular terminal
class Terminal::Widgets::TerminalCapabilities {
    #| Largest supported symbol repertoire
    has SymbolSet:D $.symbol-set = ASCII;

    #| Supports VT100 box drawing glyphs (nearly universal, but only *required* by WGL4)
    has Bool $.vt100-boxes = $!symbol-set >= WGL4;

    # Feature flags, with defaults based on majority of Terminal::Tests
    # screenshot submissions (True iff universally supported or nearly so)
    has Bool $.bold        = True;   #= Supports bold attribute
    has Bool $.italic      = False;  #= Supports italic attribute
    has Bool $.inverse     = True;   #= Supports inverse attribute
    has Bool $.underline   = True;   #= Supports underline attribute

    has Bool $.color3bit   = True;   #= Supports original paletted 3-bit color
    has Bool $.colorbright = False;  #= Supports bright foregrounds for 3-bit palette
    has Bool $.color8bit   = True;   #= Supports 6x6x6 color cube + 24-value grayscale
    has Bool $.color24bit  = False;  #= Supports 24-bit RGB color


    #| Find best symbol set supported by this terminal from a list of choices
    method best-symbol-set(@sets) {
        @sets.map({ SymbolSet::{$_} // ASCII }).grep(* <= $.symbol-set).max
    }

    #| Choose the best choice out of options keyed by required symbol set
    method best-symbol-choice(%options) {
        %options{self.best-symbol-set(%options.keys)}
    }
}
