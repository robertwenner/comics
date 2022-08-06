# Checks

Checks can warn you about something in your comic, for example if you always
want to publish your comics on Friday, you can add a Weekday check that
warns you if you specify a date that isn't a Friday. (Date calculations are
hard!)

If there is no Checks section in the configuration file(s), all Checks are
used. To disable all Checks, define an empty "Checks":

```json
{
    "Checks": []
}
```

To disable a single check, don't include it in the `Checks` section.

Available checks are all Perl modules found on your system where the name
starts with `Comic::Check::`.

Some checks take arguments (see their descriptions). Because of the JSON
syntax, you still need to include empty curly or square braces after the
check name, even if you don't pass arguments.

```json
{
    "Checks": {
        "Comic::Check::Actors": []
    }
}
```

Each comic can override the globally configured checks; see the
[metadata](metadata.md) documentation.

When a comic is checked, each Check can report problems to that particular
comic, which can then print them, or store them and make them available to
templates.


## `Comic::Check::Actors`

Checks that the given Comic's actors don't have empty names (probably
forgotten to enter a name) and that each language has the same number of
actors (assuming the comic is the same in different languages, it should
also have the same number of actors in each language).

Actors metadata is expected to be an array at `who` -> `language`.

In the following example you'll get an error because the English character
list has less items than the others.

```json
{
    "who": {
        "english": ["Paul", "Max"],
        "deutsch": ["Paul", "Max", "sprechendes Bierfaß"],
        "español": ["Paulo", "Max", "el barril que habla"]
    }
}
```


## `Comic::Check::DateCollision`

Checks that comics are not published on the same day in the same location.

For regularly published comics you may want to avoid publishing more than
one comics on the same date. However, it's probably fine to publish a comic
in different locations on the same day, or different comics in different
languages on the same day.

Dates need to be in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601)
format, without time.

`Comic::Check::DateCollision` will fail if you have two comics with the same
languages and this metadata:

```json
{
    "published": {
        "when": "2020-01-20",
        "where": "web"
    }
}
```

It would not fail if one of the comics had either a different date (`when`)
or a different location (`where`), or if one the comics didn't have the same
languages.

This check ignores comics without a published date or with an empty
published date.


## `Comic::Check::DontPublish`

Checks the comics for special markers. If any of the special markers appears
in any text in the comic, the comic is flagged with a warning.

The idea is that you can leave yourself reminders (to do items) in the comic
for things you want to get back to before it's published. The idea comes
from software development, where you may want to revisit areas of the code
before committing to source control; see [Don't commit: Avoiding
distractions while coding](https://www.sparkpost.com/blog/dont-commit-avoiding-distractions-while-coding/).

When using this Check, you must configure it and tell it which markers it
should look for. In your settings file, use something like this:

```json
{
    "Checks": {
        "Comic::Check::DontPublish": ["DONT_PUBLISH", "FIXME"]
    }
}
```

Now any comic that has `DONT_PUBLISH` or `FIXME` anywhere will be flagged.


## `Comic::Check::DuplicatedTexts`

Checks that the given comic has no duplicated texts, which could be copy
& paste errors and texts forgotten to translate.

Before comparing, texts are normalized: line breaks are replaced by spaces,
multiple spaces are reduced to one. However, checks are case-sensitive, so
that you can still use "Pale Ale" in German and "pale ale" in English.

If a comic defines a meta variable `allow-duplicated`, these texts are not
flagged as duplicated. This also works for multi-line texts; just use a
regular space instead of a line break when configuring this.

For example:

```json
{
    "allow-duplicated": [
        "Pils", "multi line text"
    ]
}
```

Any text that looks like a speaker introduction (i.e., ends in a colon) is
allowed to be duplicated as well, so that characters can have the same names
in different languages without having to define an `allow-duplicated`
exception each time.


## `Comic::Check::EmptyTexts`

Checks that the given comic doesn't have empty texts. Empty texts were
probably added by accident. They can confuse other checks or tools.


## `Comic::Check::Frames`

Checks a comic's frame style, width, and positions. Warns if frames (i.e.,
borders around the images) are inconsistent within a comic: too little or
too much space between frames, frames not aligned with each other, some
frames thicker than others.

If you use a template for your comics that already has the frames, this
check probably won't find anything. But while you work on that template, or
when you need a layout that doesn't have a template yet, this check could
be helpful.

You can configure this Check's pickiness by passing these arguments:

* FRAME_ROW_HEIGHT: After how many pixels difference to the previous frame a
  frame is assumed to be on the next row.

* FRAME_SPACING: How many pixel space there should be between frames. The
  same number is used for both vertical and horizontal space.

* FRAME_SPACING_TOLERANCE: Maximum additional tolerance when looking whether
  frames are spaced as expected.

* FRAME_TOLERANCE: Tolerance in pixels when looking for frames.

* FRAME_WIDTH: Expected frame thickness in pixels.

* FRAME_WIDTH_DEVIATION: Allowed deviation from expected frame width in
  pixels. This is used to avoid finicky complaints about frame width that
  are technically different but look the same for human eyes.

For example, this configuration will expect frames to be 2 pixels wide, but
will still accept anything between 1.5 and 2.5 pixels:

```json
{
    "Checks": {
        "Frames": {
            "FRAME_WIDTH": 2,
            "FRAME_WIDTH_DEVIATION": 0.5
        }
    }
}
```

Frames must be in a layer named "Frames".


## `Comic::Check::ExtraTranscriptLayer`

Checks the comic's extra transcript layers. These layers should contain
explanatory texts for what's going on in the comic. They are not included in
the exported comic images. This can be used to generate a transcript of the
comic for search engines or screen readers.

This check makes sure an extra transcript layer exists for each language in
the comic, that these extra transcript layers have texts, and that the first
text for each language comes from the language's extra transcript layer.

When you configure this Check, you need to configure the prefix for these
extra transcript layers globally.

The transcript generator uses the layers where the name is this meta prefix
followed by the language. For example, if prefix is `Meta` and language
is `English`, the comic is expected to have an Inkscape layer called
`MetaEnglish`.

```json
{
    "LayerNames": {
        "TranscriptOnlyPrefix": "Meta"
    },

    "Checks": {
        "Comic::Check::ExtraTranscriptLayer": []
    }
}
```


## `Comic::Check::Series`

Checks the given comic's series meta information to catch copy and paste
errors or when a comic belongs to a series in one language but not in
another (which seems odd).

Your comic needs to have metadata like this following:

```json
{
    "series": {
        "english": "Brewery Tour",
        "deutsch": "Brauereitour"
    }
}
```

You will also get a warning if there is only one comic in a series. This
could be a typo, or it could be ok (first comic in a series).


## `Comic::Check::Spelling`

Spellchecks the given comic. Inkscape has built-in spell checking, but
doesn't know which texts are in which language. Inkscape also doesn't check
comic metadata. Hence this check.

You can configure words to be ignored either in the spell checker (so that
they are ignored whenever you spellcheck anything; see below), in the main
configuration file (to always ignore them when checking your comics), or in
the comic (to only ignore them in that particular comic), or with a user
defined dictionary:

```json
{
    "Checks": {
        "Comic::Check::Spelling": {
            "ignore": {
                "English": [ "word", "otherword" ]
            },
            "user_dictionary": {
                "English": "path/to/dictionary"
            },
            "print_unknown_quoted": true,
            "print_unknown_xml": true,
            "print_unknown_lines": true
        }
    }
}
```

If `print_unknown_quoted` is true, prints a summary of unknown words ready
for copying and pasting into the comic's ignore list.

If `print_unknown_xml` is true, prints a summary of unknown words in XML
format ready for copying and pasting into the comic's ignore list; this is
for people who manually edit the XML in the `.svg` files.

If `print_unknown_lines` is true, print the unknown words each on its own
lines, for copying them into a user dictionary.

Note that any Check added in the comic overrides globally defined ones. If you
want to use a `print_unknown_...` option, you should also include it in each
comic that defines a `Comic::Check::Spelling` check (i.e., in your comic
template).

Spellchecking requires either `hunspell` or GNU `aspell`. You need to
install one of them plus its development dependencies in the operating
system, e.g., for aspell on Ubuntu use

```shell
sudo apt-get install aspell libaspell-dev aspell-en aspell-de
```

Add additional languages (like `aspell-de` above for German) as needed.
If you don't install a needed language, all words will be flagged as typos
when trying to spellcheck that language.

The `Comic::Check::Spelling` only *reports* unknown words. It's not
interactive: you cannot add unknown words to the dictionary on he fly and
you cannot enter corrections.

You have three ways to deal with unknown words that are not typos:

* Add them to your general dictionary.

* Add them to a user-defined dictionary.

* Add them to the comic's ignore list.

Adding the to your general dictionary means to add the words to a plain text
file and run the spellchecker interactively on that file, accepting all
unknown words. Here is an example for `aspell`:

```shell
echo word > en.txt
aspell --lang en check en.txt
# accept words manually
rm en.txt
```

Repeat for other languages using the language's code.

All words so added are always known in that spell checker. Do this for
common words.

Adding words to a user-defined dictionary means to place the words to ignore
in a plain text file, each on a line on its own. Pass that file in the
`user_dictionary` option. If you put that option in your main configuration
file, all comics will us it, but any other spell checking on your system
will not.

To add  words to the comic's ignore list edit your comic in Inkscape
(or in an XML editor if you're brave or hate the tiny input dialog in
Inkscape; `.svg` is XML after all) and add a `Check` section with the
words to ignore to the comic's metadata. The syntax is as above for the
configuration file. Use this option for words that are specific to open
particular comics. These words will still be flagged as typos in other
comics.


## `Comic::Check::Tag`

This flags comics that contain tags that differ from previously seen tags in
case or whitespace only. This may help with case- and whitespace sensitive
tag clouds.

You need to configure this Check and pass the tags you want to check. For
example, to check `tag` and a `who`, put this in your settings:

```json
{
    "Checks": {
        "Comic::Check::Tag": [ "tag", "who" ]
    }
}
```

This check expects comic metadata like this:

```json
{
    "tags": {
        "english": [
            "brewing", "pale ale", "malt"
        ],
        "deutsch": [
            "brauen", "Pale Ale", "Malz"
       ]
    },
    "who": {
        "english": [
            "Max", "Paul"
        ],
        "deutsch": [
            "Max"
        ]
    }
}
```

The above example would be flagged cause the German `who` has only Max when
the English one has Max and Paul.


## `Comic::Check::Title`

Checks a comic's title to prevent duplicate titles. Duplicate titles make it
impossible to uniquely refer to a particular comic by title and could lead
to filename and URL clashes when the title is used for the output image and
HTML page filenames.

This check is done per language, so you can have e.g., an English and a
German comic named "Pale Ale".

The title is expected in the comic metadata like this:

```json
{
    "Title": {
        "english": "Smoked beer",
        "deutsch": "Rauchbier"
    }
}
```


## `Comic::Check::Transcript`

Checks a comic's transcript for meta information and real comic text order.
In particular, this checks that the a comic's transcript always has a
speaker indicator before regular text. This helps to generate a transcript
where the meta layer has an indicator of what's happening and who says
something, and the real language layer has the text that the actors actually
say. A speaker indicator is a text that ends with a colon.

Texts are ordered for comparison per frames row from top to bottom and from
left to right.

This assumes that you have a layer per language, and within that the actual
text and metadata layers.


## `Comic::Check::Weekday`

Checks a comic's published date is always on certain weekdays. For regularly
published comics, it may make sense to check that a comic is always
scheduled on the same weekdays, e.g., every Friday, or every Monday and
Friday.

To use this check, configure the weekday(s). Use 1 for Monday, 2 for
Tuesday, and so on. If no weekday is given, this check is effectively
disabled.

For example, if you use the configuration below, all comics will be checked
for Tuesday and Friday.

```json
{
    "Checks": {
        "Comic::Check::Weekday": [2, 5]
    }
}
```

The following metadata fragment would make this check fail, cause Halloween
2020 was on a Saturday:

```json
{
    "published": {
        "when": "2020-10-31",
        "where": "web"
    }
}
```

Comics without a published date are silently ignored.
