# ABSTRACT: Registration and tracking for Widget subclasses and their Layout classes


#| Information tracked for each registration
my class RegistryEntry {
    has Str:D $.moniker      is required;
    has Str:D $.builder-name is required;
    has Any:U $.widget-class is required;
    has Any:U $.layout-class is required;
}


# Lock controlling access to registry
my Lock:D $registry-lock .= new;

# Actual registry hash
my %registry;


#| Registry for Widget subclasses and matching Layout classes
role Terminal::Widgets::WidgetRegistry {
    method register-widget(Str:D :$moniker!, Str:D :$builder-name!,
                           Any:U :$widget-class!, Any:U :$layout-class!) {
        my $entry = RegistryEntry.new(:$moniker, :$builder-name,
                                      :$widget-class, :$layout-class);

        $registry-lock.protect: { %registry{$moniker} = $entry }
    }

    method registry-entry(Str:D $moniker) {
        $registry-lock.protect: { %registry{$moniker} }
    }

    method widget-exists(Str:D $moniker) {
        $registry-lock.protect: { %registry{$moniker}:exists }
    }

    method known-widgets() {
        $registry-lock.protect: { %registry.keys.sort }
    }

    method builder-name(Str:D $moniker) {
        my $entry = self.registry-entry($moniker);
        $entry ?? $entry.builder-name !! Nil
    }

    method widget-class(Str:D $moniker) {
        my $entry = self.registry-entry($moniker);
        $entry ?? $entry.widget-class !! Nil
    }

    method layout-class(Str:D $moniker) {
        my $entry = self.registry-entry($moniker);
        $entry ?? $entry.layout-class !! Nil
    }
}
