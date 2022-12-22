# Settings

The Comics module accepts settings / configuration in relaxed
[JSON](https://www.json.org/json-en.html) format. You can have multiple
configuration files where settings in later ones override settings in
earlier ones.

Settings are case-sensitive (i.e., "Checks" and "checks" are *not* the
same). Currently, unknown settings are silently ignored, but this may change
in future versions.

The configuration has a top-level JSON object. Any settings are children of
this top-level object.


## Basic Settings

You can configure these at the top level:

* Artist: Your name, optionally with an email address. This is inserted into
  the `png`'s meta information.
* Author: Like for Artist, in case these differ.
* Copyright: The copyright or license for your comic. This is inserted into
  the `png`'s meta information.

For example:

```json
{
    "Author": "Me",
    "Copyright": "CC BY-NC-ND  4.0"
}
```

`Paths` configures where generated files are placed.

```json
{
    "Paths": {
        "siteComics": "c",
        "published": "generated/web",
        "unpublished": "generated/backlog"
    }
}
```

* `siteComics` gives the folder (relative to the web site root) where
  generated comics should be saved, in the example above in the `c` folder.
  The default value is "comics".
* `published` is the folder where published comics should be placed, in the
  example above in `generated/web` (this is also the default).
* `unpublished` is the folder where to place not yet published comics, in
  the example above to `gnerated/backlog`. This is also the default.


```json
{
    "LayerNames": {
        "TranscriptOnlyPrefix": "Meta"
    }
}
```

Configures layer names to indicate which layer has which information. See
the [checks](checks.md) chapter on how these are used.


## Checks

The Checks settings configure which automatic Checks you want to run on each
comic.

```json
{
    "Checks": {
        "Weekday": [5]
    }
}
```

See the chapter on [checks](checks.md) for details.


## Output

Under the Output section go any modules configuration that you want to use
to generate some output files.

See the chapter on [outputs](outputs.md) for details.
