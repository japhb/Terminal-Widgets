# ABSTRACT: Registration and tracking for Widget subclasses and their Layout classes


#| Information tracked for each registration
my class RegistryEntry {
    has Str:D $.moniker      is required;
    has Str:D $.builder-name is required;
    has Any:U $.widget-class is required;
    has Any:U $.layout-class is required;
}


my Lock:D $registry-lock .= new;  #= Lock controlling access to registry
my        %registry;              #= Primary registry: moniker to RegistryEntry
my        %layout-class;          #= Cache: builder-name to layout-class
my        %widget-class{Any};     #= Cache: layout-class to widget-class


#| Registry for Widget subclasses and matching Layout classes
role Terminal::Widgets::WidgetRegistry {
    #| Register a widget class and related details
    method register-widget(Str:D :$moniker!, Str:D :$builder-name!,
                           Any:U :$widget-class!, Any:U :$layout-class!) {
        my $entry = RegistryEntry.new(:$moniker, :$builder-name,
                                      :$widget-class, :$layout-class);

        $registry-lock.protect: {
            %registry{$moniker}          = $entry;
            %layout-class{$builder-name} = $layout-class;
            %widget-class{$layout-class} = $widget-class;
        }
    }


    ### BASIC LOOKUPS

    method registry-entry(Str:D $moniker) {
        $registry-lock.protect: { %registry{$moniker} }
    }

    method layout-for-builder(Str:D $builder-name) {
        $registry-lock.protect: { %layout-class{$builder-name} }
    }

    method widget-for-layout($layout-class) {
        $registry-lock.protect: { %widget-class{$layout-class} }
    }


    ### EXISTENCE CHECKS

    method widget-exists(Str:D $moniker) {
        $registry-lock.protect: { %registry{$moniker}:exists }
    }

    method builder-exists(Str:D $builder-name) {
        $registry-lock.protect: { %layout-class{$builder-name}:exists }
    }

    method layout-exists($layout-class) {
        $registry-lock.protect: { %widget-class{$layout-class}:exists }
    }


    ### KNOWN TYPE ITERABLES

    method known-widgets() {
        $registry-lock.protect: { %registry.keys.sort }
    }

    method known-builders() {
        $registry-lock.protect: { %layout-class.keys.sort }
    }

    method known-layout-classes() {
        $registry-lock.protect: { %widget-class.keys }
    }

    method known-widget-classes() {
        $registry-lock.protect: { %widget-class.values }
    }


    ### REGISTRY ENTRY ACCESSOR HELPERS

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
