# Styles and Themes

Separable styles

* Layout styles - compactness, border widths, etc.
* Color styles - foreground, background, attributes
* Misc styles - rounded v. square corners, single v. double borders, etc.
* Density - information density, visual density


Automatic density methods (in decreasing priority)

* Margin-collapse
* Margin shrink
* Border shrink
* Padding shrink
* Margin removal
* Padding removal
* Border faking (underline + left/right with no top?)
* Border removal


Patterns

* Border patterns
* Background patterns
* Color patterns


Fallbacks

* Fallback method: Requested versus computed!
* Color fallbacks
  * 24 bit -> 8 bit -> 4 bit?
  * Specify all colors in RGB nums?
* Attribute fallbacks: Poorly supported attributes?
  * Bold -> brighter colors
  * Inverse -> swap fg/bg
  * Underline -> ?
  * Italic -> ?  # Unicode 3.1 mathematical italics?
* Symbol set for borders
  * Support levels:
    * Rounded: Uni1
    * Heavy:   Uni1
    * Double:  WGL4
    * Single:  VT100
  * Rounded -> square corners
  * Heavy   -> (double | light)  # Choose based on visual style?
  * Double  -> light
  * Light   -> ASCII
* Symbol set for scrollbars, etc.
  * Horizontal arrows
    * ASCII:  < >  (Inverted maybe?)
    * Latin1: « »
    * WGL4:   ◄ ►
    * Uni1:   ◀ ▶
    * Uni7:   ⯇ ⯈
  * Vertical arrows
    * ASCII:  ^ v  (Inverted maybe?)
    * WGL4:   ▲ ▼
    * Uni7:   ⯅ ⯆
  * Scroll bar
    * Inverted proportional area?
    * Icon on bar?
    * Combo of above?
  * Handling of very small scrollbars?
    * 1 cell - single arrow (or double-headed arrow) indicating available scroll directions?
    * 2 cells - just end arrows
    * 3-4 cells - end arrows and space between?  icon?
    * 5+ cells - normal usage
