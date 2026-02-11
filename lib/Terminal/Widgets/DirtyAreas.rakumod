# ABSTRACT: Role for dirty area handling (primarily used by Widget)


#| Role for dirty area handling (primarily used by Widget)
role Terminal::Widgets::DirtyAreas {
    # ROLE INVARIANTS:
    #   * Attributes are not touched without holding the dirty-lock
    #   * The dirty-lock is held only when needed
    #   * All dirty-rects are within the bounds of the widget grid
    #     (and clipped in add-dirty-rect to ensure that)

    has @!dirty-rects;   #= Dirty rectangles that must be composited into parent
    has Bool:D $!all-dirty   = True;  #= Whether entire widget is dirty (optimization)
    has Lock:D $!dirty-lock .= new;   #= Lock on modifications to dirty list/flag

    # REQUIRED
    method grid() { ... }

    #| Check if parent exists and is dirtyable
    method parent-dirtyable() {
        $.parent && $.parent ~~ Terminal::Widgets::DirtyAreas
    }

    #| Determine whether the widget is *in any way* dirty (has all-dirty set or
    #| has any current dirty-rects, regardless of their location and extent)
    method is-dirty() {
        $!dirty-lock.protect: {
            $!all-dirty || ?@!dirty-rects
        }
    }

    #| Set the all-dirty flag
    method set-all-dirty(Bool:D $dirty = True) {
        $!dirty-lock.protect: {
            $!all-dirty = $dirty;
        }
    }

    #| Add a dirty rectangle to be considered during compositing
    method add-dirty-rect($x, $y, $w, $h) {
        # Clip to widget grid extent to maintain invariant that all dirty
        # rects are inside the widget bounds.
        my $rect := $.grid.clip-rect($x, $y, $w, $h);
        if $rect[2] && $rect[3] {
            $!dirty-lock.protect: {
                @!dirty-rects.push($rect) unless $!all-dirty;
            }
        }
    }

    #| Return a copy of the current dirty areas without modification
    #| (unlike snapshot-dirty-areas, this does NOT clear the internal state)
    method current-dirty-areas() {
        my @dirty;
        $!dirty-lock.protect: {
            @dirty = $!all-dirty ?? ((0, 0, $.w, $.h),) !! @!dirty-rects;
        }
        @dirty
    }

    #| Snapshot current dirty areas, clear internal state, and return snapshot
    #| (same as current-dirty-areas, with the addition of state clearing)
    method snapshot-dirty-areas() {
        my @dirty;
        $!dirty-lock.protect: {
            @dirty = $!all-dirty ?? ((0, 0, $.w, $.h),) !! @!dirty-rects;
            @!dirty-rects = Empty;
            $!all-dirty   = False;
        }
        @dirty
    }

    #| Merge and simplify dirty area list, returning a hopefully shorter list
    method merge-dirty-areas(@dirty) {
        #  Note: There is a lot of room for optimization tradeoffs here.
        #  The initial algorithm is very simple (simply bounding the AABBs),
        #  but a more advanced algorithm might for instance try to isolate
        #  disjoint areas to reduce unneeded 'clean area' copying.

        # If there's nothing to merge, just pass through
        return @dirty if @dirty <= 1;

        # Otherwise, start merging axis-aligned bounding boxes, converting
        # as needed between rect (x, y, w, h) and AABB (x1, y1, x2, y2) forms.
        my $first = @dirty[0];
        my $x1    = $first[0];
        my $y1    = $first[1];
        my $x2    = $first[0] + $first[2] - 1;
        my $y2    = $first[1] + $first[3] - 1;

        for 1 ..^ @dirty {
            my $dirty = @dirty[$_];
            $x1 min= $dirty[0];
            $y1 min= $dirty[1];
            $x2 max= $dirty[0] + $dirty[2] - 1;
            $y2 max= $dirty[1] + $dirty[3] - 1;
        }

        # Final conversion back to (x, y, w, h) form as only merged rect
        my $rect   = ($x1, $y1, $x2 - $x1 + 1, $y2 - $y1 + 1);
        my @merged = $rect,;
    }

    #| Summarize dirty-rects state for Widget gist without changing dirty state
    method gist-dirty-areas() {
        $!dirty-lock.protect: {
            # $soft-all is a heuristic for 'a single dirty rect covers the
            # whole widget by itself, even if $!all-dirty is not set'.  Note
            # this explicitly *ignores* the clipped-to-grid invariant, because
            # gist is likely used for debugging -- thus we want to cleanly
            # handle the case that the invariant has been broken by a bug.
            my $soft-all = @!dirty-rects.first({ .[0] <= 0
                                              && .[1] <= 0
                                              && .[2] >= $.w - .[0]
                                              && .[3] >= $.h - .[1] });
            $!all-dirty   ?? 'ALL' !!
            $soft-all     ?? 'soft-all' !!
            @!dirty-rects ?? @!dirty-rects.raku !!
                             'none';
        }
    }
}
