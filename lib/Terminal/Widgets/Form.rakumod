# ABSTRACT: A (non-visual) container for form inputs

class Terminal::Widgets::Form {
    has @.inputs;

    method add-input($input) {
        @!inputs.push($input);
    }
}
