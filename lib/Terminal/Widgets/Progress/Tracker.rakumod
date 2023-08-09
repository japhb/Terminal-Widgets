#| A general role for progress tracking widgets (progress bars, spinners, throbbers, etc.)
role Terminal::Widgets::Progress::Tracker {
    has $.max      = 100;
    has $.progress = 0;

    has $!progress-supplier = Supplier.new;
    has $!progress-supply = $!progress-supplier.Supply;

    submethod TWEAK() {
        # Update progress bar display whenever supply is updated
        $!progress-supply.act: -> (:$key, :$value) {
            self!update-progress: $!progress * ($key eq 'add') + $value
        }

        self.set-progress($!progress);
    }

    #| Add an increment to the current progress level
    method add-progress($increment) {
        $!progress-supplier.emit('add' => $increment);
    }

    #| Set the current progress level to an absolute value
    method set-progress($value) {
        $!progress-supplier.emit('set' => $value);
    }

    #| Set the current progress level to the max value to indicate complete
    method set-complete() {
        $!progress-supplier.emit('set' => $.max);
    }

    #| Stub to allow instantiating a do-nothing class punned from this role;
    #| override in any real composing class.
    method !update-progress($p) { }
}
