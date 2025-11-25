# Text Content Model

In order to support many use cases securely, Terminal::Widgets has a somewhat
complex content model _internally_, with simpler interfaces built on those
internals that the app developer can use confidently.


## Layering and Conversions

To support all the different desired use cases, Terminal::Widgets uses a
hierarchy of text content types, each convertible to the next.  Here's an
example of the process, starting from a `TranslatableString`:

```
TranslatableString — 'It is not ${c:important|diagnosis}.'
  │
  ▼
MarkupString       — 'Itway isway otnay ${c:important|diagnosis}.'
  │
  ▼
SpanTree           — SpanTree(StringSpan('Itway isway otnay '),
  │                           InterpolantSpan(var   => 'diagnosis',
  │                                           class => 'important'),
  │                           StringSpan('.'))
  ▼
Array[StringSpan]  — [StringSpan('Itway isway otnay '),
  │                   StringSpan('ibblestray',
  │                              attributes => %(:important, :interpolation)),
  │                   StringSpan('.')]
  ▼
Array[RenderSpan]  — [RenderSpan('',         'Itway isway otnay '),
  │                   RenderSpan('bold red', 'ibblestray'),
  │                   RenderSpan('',         '.')]
  ▼
Str                — 'Itway isway otnay ibblestray.'
```

Here's what the conversion pipeline looks like under the covers:

```
TranslatableString — Highest level, opaque (though often in source language)
  │
  │ .translate       ⚙️ Look up translated variant that matches interpolant vars
  ▼
MarkupString       — Includes inline semantic markup of spans and interpolants
  │
  │ .parse           ⚙️ Parse markup into a tree of typed spans
  ▼
SpanTree           — Tree of SemanticSpans (InterpolantSpan or StringSpan)
  │
  │ .flatten         ⚙️ Flatten tree into single list of SemanticSpans
  │
  │ .interpolate     ⚙️ Interpolate variables into InterpolantSpans
  ▼
Array[StringSpan]  — Flattened (and if necessary interpolated) renderable spans
  │
  │ .render          ⚙️ Render (StringSpan + attributes) into (RenderSpan + color)
  ▼
Array[RenderSpan]  — Flat array of RenderSpans for Widget.draw-line-spans
  │
  │ plain-text()     ⚙️ (OPTIONAL) Join text from RenderSpans into a plain Str
  ▼
Str                — Just a plain string, for use where color doesn't matter
```


## Performance

While every attempt has been made to make individual operations efficient, it's
obvious that a long pipeline will build up overhead, and some operations may be
slow enough to be prohibitive when dealing with high volumes of text content.
It is rarely necessary however to repeat the early stages of the pipeline on
every screen refresh.  Translations for strings that don't contain any
interpolations will generally be static per language for a given software
release, for example.

Thus `ContentRenderer` and its subclass `TranslatableContentRenderer` provide
convenience methods that will drive rendering starting at any point in the
render pipeline and ending at any point farther along.  This both improves
testability/debuggability, and allows caching of partially-completed rendering
work.


## Security

It is a critical design feature that the render pipeline is **one way**.  This
prevents a number of security and correctness bugs that would be caused by for
instance accidentally parsing markup within the results of a variable
interpolation.

Furthermore `TranslatableString` and `MarkupString` both default to NOT
allowing generation of InterpolantSpans, so string contents that only
coincidentally contain variable interpolation markup pose no threat.  The
programmer must explicitly mark a string as interpolatable _out of band_
to turn this functionality on.

All of the semantic classes (those other than `Str` and `RenderSpan`) throw a
special exception `X::CannotStringify` if an attempt is made to stringify them
without going through the proper stages of the conversion pipeline.
