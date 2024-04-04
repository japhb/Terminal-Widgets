# ABSTRACT: Role for inputs that have a label 'attached' to them, such as radio buttons

role Terminal::Widgets::Input::Labeled {
    # XXXX: Need a 'defined textual content' type constraint
    has $.label = '';

    method set-label($!label) { self.full-refresh }
}
