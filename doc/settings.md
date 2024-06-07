# Settings

The Comics module accepts settings / configuration in relaxed
[JSON](https://www.json.org/json-en.html) format. You can have multiple
configuration files where settings in later ones override settings in
earlier ones.

All settings are case-sensitive (i.e., "Checks" and "checks" are *not* the
same). Currently, unknown settings are silently ignored, but this may change
in future versions.

The configuration has a top-level JSON object. Any settings are children of
this top-level object.


## Basic Settings

You can configure these at the top level:

* Artist: Your name, optionally with an email address. This is inserted into
  the `png`'s meta information.
* Author: Like for Artist, in case these differ.
* Copyright: The copyright or license for your comic. This is e.g., inserted
  into the `png`'s meta information.

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
        "siteComics": "ccc",
        "published": "generated/web",
        "unpublished": "generated/backlog"
    }
}
```

* `siteComics` gives the folder (relative to the website root) where
  generated comics should be saved, in the example above in the `ccc`
  folder. The default value is "comics".
* `published` is the folder where published comics should be placed, in the
  example above in `generated/web` (this is also the default).
* `unpublished` is the folder where to place not yet published comics, in
  the example above to `gnerated/backlog`. This is also the default.


```json
{
    "LayerNames": {
        "TranscriptOnlyPrefix": "Meta",
        "NoTranscriptPrefix": "NoText",
        "Frames": "Rahmen"
    }
}
```

Configures layer names to indicate which layer has which information. See
the [checks](checks.md) chapter on how these are used.

When the Comic modules process your comics, they run in this order: first,
all checks run, but the order of the checks is undefined. Checks may be
skipped for comics that haven't changed, to speed up things.

Then all output generators run. They run in a predefined order, as some
output generators need data from previous ones, for example, the HTML
archive page generator can only run once the comic pages have been written.

When all output generators have finished, the uploaders run, to get your
comics published.

After everything is uploaded, social media posters run, to let the world
know about your latest comic.


## Checks

The Checks settings configure which automatic Checks you want to run on each
comic.

```json
{
    "Checks": {
        "Comic::Check::Weekday": [5]
    }
}
```

See the chapter on [checks](checks.md) for details.


## Output generators

Under the Out section go any modules configuration that you want to use
to generate some output files.

```json
{
    "Out": {
       "Comic::Out::SvgPerLanguage": {
            "outdir": "generated/svg"
        },
        "Comic::Out::HtmlLink": {
        },
        "Comic::Out::PngInkscape": {
            "outdir": "generated/web"
        },
        "Comic::Out::HtmlComicPage": {
            "outdir": "generated/web",
            "template": "templates/comic-page.templ"
        }
    }
}
```

See the chapter on [outputs](outputs.md) for details.


## Uploader

Under the "Uploader" section go all modules that copy or upload your web
comics somewhere.

```json
{
   "Uploader": {
        "Comic::Upload::Rsync": {
            "sites": [
                {
                    "source": "generated/web/deutsch/",
                    "destination": "you@your-german-domain/comic-folder/"
                },
                {
                    "source": "generated/web/english/",
                    "destination": "you@your-english-domain/comic-folder"
                }
            ]
        }
    }
}
```


## Social

All modules that let the world know about your latest comics, e.g., social
media posting modules, are configured under the "Social" section.

```json
{
    "Social": {
        "Comic::Social::Mastodon": {
            "access_token": "...",
            "instance": "mstdn.io",
            "mode": "png"
        }
    }
}
```

See the [social media posters](social.md) documentation for details.
