# Metadata

The Comic modules assume that the comic and all its data is in the Inkscape
`.svg` file, as opposed to e.g., having a separate file for the transcript
or even a database for additional information on a comic.

The metadata of a comic needs to be in the Inkscape's Description field. In
Inkscape, click the "File" menu, then "Document Properties...", or press
Ctrl + Alt + D. Go to the "Metadata" tab, then scroll down to the
"Description" field.

While some other fields in the metadata like author and date could be used,
most of them like title don't support multiple languages. Hence the Comic
modules ignore all Inkscape metadata and instead only work with (you could
say abuse) the description.

The description must be a [JSON](https://www.json.org/json-en.html) object.
That means it must be included in curly braces, and then the metadata is
given as keys and values, like this:

```json
{
    "title": {
        "English": "Karma",
        "Deutsch": "Karma"
    },
    "description": {
        "English": "All about karma",
        "Deutsch": "Alles Karma"
    }
}
```

The `title` is most important: if a comic doesn't have a title for a given
language, it doesn't exist in that language. When code processes a comic, it
always asks for the comic's language by looking at the `title` metadata.
This is a convenient mechanism to keep a language out: When you want to
support a new language, you can already translate and add everything except
the title, and only when all comics are available in that language and
you're ready to go, add the titles.

Different [check](checks.md) and [output](outputs.md) modules will use
different metadata fields; see the respective documentation on what they
expect.
