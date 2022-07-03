# ABSTRACT: Role for inputs that have a label "attached" to them, such as radio buttons

role Terminal::Widgets::Input::Labeled {
    has Str:D $.label = '';

    method set-label(Str:D $!label) { self.full-refresh }
}
