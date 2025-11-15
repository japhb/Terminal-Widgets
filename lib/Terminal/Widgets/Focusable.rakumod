# ABSTRACT: Base role for widgets that can be focused / interacted with


#| Role marking a widget as focusable and focus-navigable
role Terminal::Widgets::Focusable {
    #| Add focus marker to gist-flags
    method gist-flags() {
       |callsame,
       ('FOCUSED' if self.toplevel.focused-widget === self),
    }

    #| Move focus to next Focusable circularly
    method focus-next() {
        with self.next-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
        orwith self.toplevel.first-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
    }

    #| Move focus to previous Focusable circularly
    method focus-prev() {
        with self.prev-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
        orwith self.toplevel.last-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
    }
}
