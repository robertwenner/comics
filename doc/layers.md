# Layers

The Comic modules use layer names to know what layers to export, what layers
have special meanings, and how to treat such layers.

There are 3 kinds of layers:

- Language layers hold language-dependent information. Their names must end in
  the language (uppercase), e.g., `English`, or `BackgroundEnglish`.

- Transcript layers: the `Comic::Out::Transcript` module generates a
  transcript of the comic. It gets the texts from the language layers, plus
  an extra layer named as the configured `ExtraTranscriptPrefix` plus the
  language name (uppercase), e.g., `MetaEnglish` if `ExtraTranscriptPrefix`
  is `Meta`.

- Frames layer: used by some checks and the transcript generator to figure
  out in which order texts should appear in the transcript.

All other layers (i.e., that don't end in a language or don't start with a
configured prefix or have a configured special name) are considered part of
the image and are left untouched.

Here is an example configuration:

```json
{
    "Layers": {
        "ExtraTranscriptPrefix": "Meta"
    }
}

```

Any layer where the name starts with `Meta` will be hidden and not exported.
