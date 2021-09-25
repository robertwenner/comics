# Output

## File name

When a file for a comic is written, the file name is derived from the comic's
title for each language.

These file names are stripped of certain characters that could cause
problems in URLs and file names: any characters that are not letters,
numbers, or hyphens will be removed; blanks will be replaces with hyphens.
For example, a title "Let's drink!" will be result in "lets-drink".


## Dependencies

Order matters in the configuration file; if you rely on the output from a
previous module, it needs to go before the module that requires the output.

For example, the `Comic::Out::QrCode` module will create QR codes for comic
pages and put the URL in the Comic. If the `Comic::Out::HtmlComicPage` module
wants to include the QR code in the page, it must run after (that means:
configured after) the `Comic::Out::QrCode` module.

Most notably: To export your comics as `.png`, you first need to export them
as per-language `.svg`s, then the `Png` module will work with the
per-language `.svg`s. This also allows to put modules between the language
splitting and `.png` conversion, for example a module to add a copyright
notice.


## Output Organization

I recommend having separate directory trees (folders) for input files and
output files. That makes it easier to not edit a generated file (and have
the changes overwritten next time output is generated) and to not delete a
not-generated file by accident. (I also recommend a version control system
and regular backups.)

Hence all generated files are placed under the directory configured as the
main output directory.

```json
{
    "Out": {
        "outdir": "generated"
    }
}
```

Comics may have different ideas on where exactly they need to go, for example
a German comic published on the web may go in `web/deutsch/comics/` while an
English comic not yet published may go in `backlog/` (both directories being
within the specified `out` directory, here `generated/`.


## `Comic::Out::Backlog`

Generates an overview of the comics in the queue, plus the tags, character
names, and series used in all comics. This should help when creating a new
comic to look up what keywords (tags) other comics used.

```json
{
    "Out": {
        "Comic::Out::Backlog": {
            "template": "templates/backlog.templ",
            "outfile": "generated/backlog.html",
            "toplocation": "web",
            "collect": [ "who", "tags", "series" ]
        }
    }
}
```

* The `template` defines the file with Perl Toolkit template to use to
  generate the actual backlog.

* The `outfile` specifies where the output (the finished backlog) should go.

* The generated backlog can be sorted by the location where the comics are
  published (`published.where` in the comic's meta data). The backlog
  template can iterate over the locations and print the backlog comics per
  location. However, if your main publishing location is e.g., "web",
  chances are you have other less important locations that would get sorted
  before "web". To see your main backlog first without having to scroll and
  without duplicating or complicating the template code, you can specify the
  `toplocation`. This will be the first item in the locations array,
  followed by all other locations in alphabetical order.

* The optional `collect` array specifies which per-language meta data from
  the comics to collect and make available. These need to be given in the
  comics like this:

```json
{
    "series": {
        "English": {
            "making beer"
        }
    },
    "who": {
        "English": [ "Max", "Paul" ]
    },
    "tags": [
        "brewing", "malt", "yeast"
    ]
}
```

   For the backlog, they will be sorted by number of occurrence, then
   alphabetically.

When the template is processed, these variables are available:

* `comics` array of all comics in the backlog, with any meta data or
  information from other output generators that already ran available.

* `languages`: array of names of all languages in all comics (published or
   not).

* `publishers`: array of locations where comics are scheduled to be
   published (from the comic's `published.where` meta data). The template
   can use this to group backlog comics by location, e.g., one list for
   online and one for a magazine.

* `x`, where x is each element in the configured `collect` parameter: a hash
   of that comic meta data to the count it occurred.

* `xOrder`, ordered by how often that x meta data has been seen in all
   comics. The template can iterate over these arrays and use the values as
   keys to the respective `x` hashes to print the them in order.

=back

Only `comics` is useful for showing how many comics are in the queue /
backlog. The other variables are meant to show what tags, series, or
characters already exist, to make it easy to align new comics with those.


## `Comic::Out::Copyright`

Places a copyright or license or URL note on the per-language `.svg` comic
(i.e., this module depends on `Comic::Out::SvgPerLanguage`).

```json
{
    "Out": {
        "Comic::Out::Copyright": {
            "text": {
                "English": "beercomics.com -- CC BY-NC-SA 4.0"
            },
            "style": "font-family: sans-serif; font-size: 10px"
        }
    }
}
```

In the above example configuration, the English comics would get the text
"beercomics.com -- CC BY-NC-SA 4.0" inserted. If other languages are present
in the comic but not in the `Comic::Out::Copyright` configuration, comic
generation will fail with an error. If you want to not add a text for other
languages, define an empty text (e.g., `"Deutsch": ""`).

The style is optional. If not specified, it defaults to a black sans-serif
font of size 10px. To pick a style, look at the XML of your comic texts
(Inkscape menu Edit, then XML Editor...) and copy a `style=` description.

The position for the Copyright note is picked automatically and depends on
the frames in the comic. If there are rows of frames, the text will be
placed between the last two rows. If all frames are in one row, the text
will be turned 90 degrees and placed between frames. If there is only one
frame, the text will go in the bottom left corner of that frame.


## `Comic::Out::Feed`

Generates website feeds (e.g., in [RSS](https://en.wikipedia.org/wiki/RSS)
or [Atom](https://en.wikipedia.org/wiki/Atom_(Web_standard) format) from
provided Perl [Template Toolkit](http://template-toolkit.org/) templates.

While not many people use RSS readers these days, feeds can be used to
trigger an action with [Zapier](https://zapier.com) like uploading the new
comic on Facebook.

```json
{
    "Out": {
        "Comic::Out::Feed": {
            "RSS": {
                "template": "path/to/rss.template"
            },
            "Atom": {
                "template": {
                    "English": "path/to/english/atom.template",
                    "Deutsch": "path/to/german/atom.template"
                },
                "max": 5,
                "output": "atom.xml"
            }
        }
    }
}
```

The above example configures two feeds, one in RSS and one in Atom format.
Each feed configuration can take these arguments:

* template (mandatory): either the template file, if all languages use the
  same template, or an object of languages to template path for different
  templates for each language. If all languages use the same template file,
  that file needs to either be language independent or check the `language`
  variable for language dependent output.

* max: how many comics to include at most in the feed. This value is
  passed to the template as `max`. Defaults to 10.

* output: the path and file name of the output file. This will always be
  within the output directory (passed in code), plus a language specific
  directory (the language name in lower case), e.g.,
  `generated/web/english/atom.xml` for the atom example above.
  Defaults to the lower-case feed name plus an `.xml` extension.

The `Comic::Out::Feed` module defines some variables for use in the template:

* `comics`: all comics, sorted from latest to oldest. All comic meta
  information is available. All comics are passed so that the template can
  decide which comics to include. This allows for language-independent
  templates at the price of higher template complexity if there are comics
  that don't exist in all languages.

* `language`: `Comic::Out::Feed` will populate the template for each language
  found; the currently processed language is in this variable.

* `max`: maximum number of feed items, as per configuration.

* `notFor`: a function that takes a comic and a language and returns a Boolean
  indicating whether the given comic is for the given language. This is used
  for comics that don't exist in all languages and allow the template to
  skip a comic that's not for the language being processed.

* `updated`: current time stamp, in [RFC 3339](https://tools.ietf.org/html/rfc3339)
  format (needed in Atom format).


## `Comic::Out::FileCopy`

Copies files. This is meant for static files of a web page, like CSS or
static HTML content.

Having this functionality within the Comic modules makes it easy to call the
whole tool chain from the command line or cron jobs without having to add
e.g., `cp -r static/all/* generated/web/` after processing the comics and
before uploading the web page.

Does not copy files that have not been modified (according to the file
system). This is so that upload tools (e.g., `rsync` without `--checksum`
option) that work on file system time stamp can decide to also not upload
unchanged files again.

The configuration looks like this:

```
{
    "Out": {
        "Comic::Out::FileCopy": {
            "outdir": "generated/web",
            "from-all": ["web/all", "misc/all"],
            "from-lamguage": "web/"
        }
    }
}
```

Output files will be copied from the `from-all` directory and the language
specific `from-language` directories into the given `outdir` plus the
language name (lower cased).

For example, for the configuration above, files for English and German
comics will be copied from `web/english` and `web/german` to
`generated/web/english/` and `generated/web/deutsch/` respectively. Files
from `web/all` will be copied to both `generated/web/english` and
`generated/web/deutsch`.

This module does *not* support modifying copied files on the fly, e.g., to
update a published date or copyright year in an otherwise static HTML pages.

This module is just a wrapper around the Linux `cp` command, so you'll
probably need to install Cygwin tools on Windows.


## `Comic::Out::HtmlArchivePage`

Generates a per-language HTML page with all published comics comics in
chronological order.

The configuration takes a template and an output file for each language:

```json
{
    "Out":
        "Comic::Out::HtmlArchivePage": {
            "template": {
                "English": "templates/archive-en.templ"
            },
            "outfile": {
                "English": "generated/web/English/archive.html"
            }
        }
    }
}
```

The templates are Perl Toolkit templates. The `outfile` specifies where to
place the output.

While processing the templates, these variables are available:

* `comics`: list of all comics to include in the archive.

* `modified`: last modification date of the latest comic, to be used in
  time stamps in e.g., HTML headers.

* `notFor`: function that takes a comic and a language and returns
   whether the given comic is for the given language. This is useful if you
   want just one template for all languages.


## `Comic::Out::HtmlComicPage`

This is the main output generator for web comics. It generates a HTML page
for each comic, plus an `index.html` overview page.

The configuration needs to be like this:

```json
{
    "Out": {
        "Comic::Out::HtmlComicPage": {
            "outdir": "generated/web",
            "templates": {
                "English": "templ/comic-page.templ"
            }
        }
    }
}
```

The `outdir` specifies the main output directory; the actual files will be
generated underneath, in a directory for each language, with the HTML file
name derived from the comic's title.

The `templates` refers to a Perl Toolkit template per language that will be
used to generate the page.

This module defines these variables in each comic, that the templates can
use:

* `htmlFile` hash of language to file name of the generated HTML file,
  derived from the comic's title, e.g., for a comic with an English title of
  "Beer brewing" this could be `beer-brewing.html`.

* `href` the path to the comic's HTML file relative to the server root,
  e.g., `comics/beer-brewing.html` for English.

* `first`, `prev`, `next`, `last` are the `htmlFile` values of the first,
  previous, next, and last comic in that language, respectively.

* `isLatestPublished`: this variable is only defined on the last published
  comic in each language. The template can query this flag and change the
  page for the last published comic.

When the template is processed, these variables are also available:

* `comic`: the current comic.

* `languages` is a list of languages used in this comic.

* `languagecodes` is a list of language codes used in this comic, e.g, "en"
  for English and "de" for German. See the [CLDR](https://cldr.unicode.org/)
  for details.

* `languageurls` hash of language to URL to link to the comic in a different
  language.

* `year` 4-digit year when the comic was created, for use in e.g., a
  copyright statement.

* `canonicalUrl` full URL of the comic.

* `comicsPath` path to comics, relative to the server root, e.g., `comics/`.

* `indexAdjust`: prefix for paths / URLs to other comics, so that navigation linking
  works in published an non-published comics.

* `root`: points to the server root, to be used to include CSS, static
  images, or JavaScript code.

The `index.html` file uses the same template as the regular comic pages.


## `Comic::Out::Png`

Generates a Portable Network Graphics (`.png`) file for from a Scalable
Vector Graphics (`.svg`) file.

The configuration looks like this:

```json
{
    "Out": {
        "Comic::Out::Png": {
            "outdir": "generated/web"
        }
    }
}
```

The generated `.png` files will be placed in a language specific directory
(lower case name of the language, e.g., "english" or "deutsch") under the
given `outdir`. Its name is derived from the comic's title in that language.

The file name will be saved in the comic as `pngFile` so that templates
like `Comic::Out::HtmlComicPage` can access it.

The following meta data will be set on the `.png` file:

* Title, taken from the Comic's meta data

* Description (as the transcript)

* `CreationTime`: as the comic's last modified date / time

* URL: the comic's canonical URL

After that, global settings for Author, Artist, and Copyright are added, if
they are defined.

Finally, if the comic has a JSON element named `png-meta-data`, its values
are taken to the `.png` file. For example

```json
{
    "png-meta-data": {
        "foo": "bar"
    }
}
```

Would set a field named "foo" to "bar".

After writing, this Generator defines these values in the comic for use in
templates or other generators:

* `pngSize`: image size in bytes, per language

* `height`: height of the images in pixels

* `width`: width of the image in pixels

Height and width are not per-language, assuming a comic has the same size in
each language.


### `Comic::Out::QrCode`

Generates a [QR code](https://en.wikipedia.org/wiki/Qr_code) with the comic
page's URL for each comic in each language. You can then include this in the
page's print version so that people can easily go from a printed comic to
the web version.

```json
{
    "Out": {
        "Comic::Out::QrCode": {
            "outdir": "generated/qr/"
        }
    }
}
```

The QR code image file name will be derived from the comic's title in the
respective languages. It will be stored in the comic in a `qrcode` hash with
the languages as keys, for use in templates or other code.


### `Comic::Out::Sitemap`

Generates a [sitemap](https://en.wikipedia.org/wiki/Sitemaps) per language.
Sitemaps can tell search engines which pages they should crawl.

```json
{
    "Out": {
        "Comic::Out::Sitemap": {
            "templates": {
                "English": "templates/sitemap-en.xml",
                "Deutsch": "templates/sitemap-de.xml",
            },
            "output": {
                "English": "generated/web/english/sitemap.xml",
                "Deutsch": "generated/web/deutsch/sitemap.xml"
            }
        }
    }
}
```

The module accepts these options:

* `templates`: object of languages to Perl Toolkit template files to use for
  that language.

* `output`: object with language to output file.

The module makes these variables available in the template:

* `comics`: sorted (oldest to latest) list of published comics.

* `notFor`: code reference to a function to check whether a given comic
  should be included in the sitemap.


### `Comic::Out::Sizemap`

Generates a size map showing all different overall sizes used in the comics.
This can help figuring out what size works nicely for one's style.

The size map is configured like this:

```json
{
    "Out": {
        "Comic::Out::Sizemap": {
            "template": "templates/sizemap.templ",
            "output": "generated/sizemap.html",
            "scale": 0.3,
            "published_color": "green",
            "unpublished_color": "blue"
        }
    }
}
```

The configuration parameters are:

* `template`: what Perl Template to use.

* `output`: to which file to write the size map.

* `scale`: by which factor to scale the shown frames; optional, defaults to
  0.3

* `published_color`: in which color to draw frames for published
  comics; optional, defaults to "green". Any SVG color specification is
  valid.

* `unpublished_color`: in which color to draw frames for unpublished
  comics; optional, defaults to "blue". Any SVG color specification is
  valid.

The template can access these variables:

* `svg`: a SVG drawing of frames for the comic sizes, can be embedded in
  HTML.

* `min`, `max`, and `avg` for `width` and `height`, i.e., `minwidth` and
  `maxheight`: The minimum, maximum, average values of height and width of
  all comics.

* `comics_by_width`: list of all comics ordered by width (widest first).

* `comics_by_height`: list of all comics ordered by height (tallest first).


### `Comic::Out::SvgPerLanguage`

Exports a `.svg` file per language in the comic. Each of these `.svg` files has
only the layers that are common for all languages and the layers for the
respective language.

To determine which layers are for a language, the code looks at the comic's
meta data in the "Description" field in Inkscape; see
[metadata](metadata.md) for details.

The `.svg` file names will be saved in the comic as `svgFile` so that later
code or templates can use them.

This is configured like this:

```json
{
    "Out": {
        "Comic::Out::SvgPerLanguage": {
            "outdir": "generated/svgs"
        }
    }
}
```

The `outdir` specifies where the generated `.svg` files should go; default
is `tmp/svg`. This module will create a directory per language in the given
output directory.
