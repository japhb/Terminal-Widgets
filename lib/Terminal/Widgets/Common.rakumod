# ABSTRACT: Role with common methods for all major T-W class hierarchies


#| Role with common methods for all major T-W class hierarchies
role Terminal::Widgets::Common {
    #| Cache of DEBUG level at time of object creation
    has UInt:D $.debug = +($*DEBUG // 0);

    #| Shortened name for gists and monikers
    method gist-name() { self.^name.subst('Terminal::Widgets::', '') }
}
