# Settings

The Comics module accepts settings / configuration in relaxed
[JSON](https://www.json.org/json-en.html) format. You can have multiple
configuration files where settings in later ones override settings in
earlier ones.

This document describes the available settings. Settings are case-sensitive
(i.e., "Checks" and "checks" are *not* the same). Unknown settings are
silently ignored.

The configuration has a top-level JSON object. Any settings are children of
this top-level object.


## Basic Settings

You can configure these at the top level:

* Artist: Your name, optionally with an email address. This is inserted into
  the PNG's meta information.
* Author: Like for Artist, in case these differ.
* Copyright: The copyright or license for your comic. This is inserted into
  the PNG's meta information.

For example:

```json
{
    "Author": "Me",
    "Copyright": "CC BY-NC-ND  4.0"
}
```


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
