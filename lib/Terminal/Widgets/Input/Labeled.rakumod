# ABSTRACT: Role for inputs that have a label 'attached' to them, such as radio buttons

use Terminal::Widgets::TextContent;

role Terminal::Widgets::Input::Labeled {
    has TextContent:D $.label = '';

    method set-label($!label) { self.full-refresh }
}
