# Layers

The Comic modules use layer names to know what layers to export, what layers
have special meanings, and how to treat such layers.

The Comic modules distinguish these layers:

- Language layers hold language-dependent information, usually the texts in
  a comic, or drawings that are only applicable in that language. Their
  names must end in the language (starting with an uppercase letter), e.g.,
  `English`, or `BackgroundEnglish` are recognized as layers for the English
  language.

- Extra transcript layers: the `Comic::Out::Transcript` module generates a
  transcript of the comic. It gets the texts from the language layers (as
  above). For a better transcript, you can add an extra layer per language
  that has texts describing what is going on in the comic. Naturally you
  don't want to export that layer in the image. To mark a layer as
  contributing to the transcript but not meant for the image, configure a
  `TranscriptOnlyPrefix`, then name these layers to start with that prefix
  and end in their language (as above).

- Background layers that don't contribute to the transcript: this is for
  per-language texts in the image that should not make it into the
  transcript. If you configure a `NoTranscriptPrefix`, the transcript
  collecting code will ignore all layers where the name starts with that
  prefix will that prefix. If you don't configure this prefix, all layers
  contribute to the transcript.

- Frames layer: used by some checks and the transcript generator to figure
  out in which order texts should appear in the transcript. You can
  configure this with the `Frames` layer name setting. Defaults to "Frames".

All other layers (i.e., that don't end in a language or don't start with a
configured prefix) are considered part of the image and are left untouched.

Here is an example configuration:

```json
{
    "Layers": {
        "TranscriptOnlyPrefix": "Meta",
        "NoTranscriptPrefix": "Background",
        "Frames": "Frames"
    }
}

```

In the above example, any layer where the name starts with `Meta` will be
hidden and not exported, but will be used for the transcript. Any layer
starting with `Background` will be exported as usual, but its texts won't
show up in the transcript. When ordering the texts, the code will look at
the rectangles in the `Frames` layer.

Note that text outside of layers will be ignored for the transcript, but
will get exported to the comic image if the layer is visible. This is
probably not what you want, so the advice is to keep all text in
language-specific layers.


You can use nested layers, e.g., have a layer named "English" and inside
that a layer for English text, English extra transcript texts, English
backgrounds, and so on, but the inner layer names must still also end in
"English" or they won't be enabled automatically. Even though the code won't
pick nested layers up for a language automatically (it just looks at layer
names without regards to their nesting), the outer nested layers are helpful
to quickly switch a language on or off in Inkscape.
