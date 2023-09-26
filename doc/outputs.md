# Output

## File name

When a file for a comic is written, the file name is derived from the comic's
title for each language.

These file names are stripped of certain characters that could cause
problems in URLs and file names: any characters that are not letters,
numbers, or hyphens will be removed; blanks will be replaces with hyphens.
For example, a title "Let's drink!" will use "lets-drink" as the (base) file
name.


## Dependencies

Some output modules depend on other output modules running first. For
example, to export your comics as `.png`, the `Comic::Out::SvgPerLanguage`
first need to export them as per-language `.svg`s, then the
`Comic::Out::PngInkscape` module will turn the per-language `.svg`s into
`.png`s.

The code is smart enough to use the modules in the right order, but it
cannot yet pull in missing modules. So to get `.png` output, you must
configure the `Comic::Out::SvgPerLanguage` as well.

The order in which these modules run is undefined, but they will only run
after all [Check](checks.md) modules have finished.


## Output Organization

I recommend having separate directory trees (folders) for input files and
output files. That makes it easier to not edit a generated file (and have
the changes overwritten next time output is generated) and to not delete a
not-generated file by accident. (I also recommend a version control system
and regular backups.)

Comics may have different ideas on where exactly they need to go, for example
a German comic published on the web may go in `web/deutsch/comics/` while an
English comic not yet published may go in `backlog/` (both directories being
within the specified `out` directory, here `generated/`).


## Caching

To speed up processing, some output generators will not run if they detect
that their output file is up to date (i.e., it was modified after the
corresponding source comic file was modified).

This also means that a configuration change, e.g., for the
`Comic::Out::Copyright` note won't get picked up automatically. In this case
delete the output directory to force re-creating everything.


## Transcript

The Comic module collects the transcript of the comic, per language. The
transcript is all texts in the comic. It can be placed in the comic's page
for search engines and people with screen readers.

Each comic can define a variable named `Transcript` in its metadata. If that
variable is not defined or has the value `left-to-right`, the comics texts
(from left to right) make up the transcript. Each row of frames is taken
separately . Anything above the first row of frames goes first (place an
introductory text there), then the first row from left to right, then the
second, and so on. Any text under the last row of frames is considered to be
its own row, so that captions always go after the comic's texts. Text
positions depend on alignment: if a text is left aligned, its position is
the left side, centered text uses the center x position, and right aligned
text uses the right-most coordinate of that text.

If `Transcript` is `from-ids`, the texts will be ordered by their ids, from
lowest to highest. This is meant for complex drawings that don't go in
classic left to right, top to bottom order. To set the id on a text element,
open the XML editor in Inkscape (Edit menu), then show attributes (if they
aren't visible by default). Select each text, click `id` in the attributes,
and enter a value. I recommend numbers, and leaving gaps: a group of texts
get e.g., 1 to 4, then the next group gets 10 to 13. That way you can easily
squeeze in more texts without having to renumber everything. For the same
reason, do numbering only when you are done with the comic's texts. Ids
*must* be unique per document; even across layers. If you try to use an id
that's already in use, Inkscape will automatically change the id of the
previous element to a generated id, so be careful. While you can pick
anything for ids, I recommend numbers. Inkscape generates ids like "text"
plus a number. If you go with numeric ids, the Comic code will complain
about a mix of numeric and alphanumeric ids, which probably indicates that
Inkscape replaced a duplicated id with a generated one and now text order is
off.


## `Comic::Out::Backlog`

Generates an overview of the comics in the queue, and the published comics,
plus the tags, character names, and series used in all comics. This should
help when creating a new comic to look up what keywords (tags) other comics
used.

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
    "tags": {
        "English": ["brewing", "malt", "yeast"]
    }
}
```

   For the backlog, they will be sorted by number of occurrence, then
   alphabetically.

When the template is processed, these variables are available:

* `unpublished_comics` array of all comics in the backlog, with any meta
  data or information from other output generators that already ran
  available. Sorted from next to be published to later scheduled comics.
  Comics not yet scheduled go last.

* `published_comics` array of all published comics, with any meta data or
  information from other output generators that already ran available.
  Sorted from latest to earliest.

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

Only `comics` is useful for showing how many comics are in the queue /
backlog. The other variables are meant to show what tags, series, or
characters already exist, to make it easy to align new comics with those.


## `Comic::Out::Copyright`

Places a copyright or license or URL note on the per-language `.svg` comic.

```json
{
    "Out": {
        "Comic::Out::Copyright": {
            "text": {
                "English": "beercomics.com -- CC BY-NC-SA 4.0"
            },
            "style": "font-family: sans-serif; font-size: 10px",
            "id_prefix": "Copyright",
            "label_prefix": "Copyright"
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
font of size 10px. (This is without regard to frame spacing.) To pick a
style, look at the XML of your comic texts (Inkscape menu Edit, then XML
Editor...) and copy a `style=` description.

Both `id_prefix` and `label_prefix` are optional and default to "Copyright".
These prefixes are used with the language name for label and id of the newly
generated layers. You can pick different ones in case you already have a
layer named e.g., `CopyrightEnglish`.

The position for the copyright note is picked automatically and depends on
the frames in the comic. If there are rows of frames, the text will be
placed between the last two rows. If all frames are in one row, the text
will be turned 90 degrees and placed between frames. If there is only one
frame, the text will go in the bottom left corner of that frame.


## `Comic::Out::Feed`

Generates website feeds (e.g., in [RSS](https://en.wikipedia.org/wiki/RSS)
or [Atom](https://en.wikipedia.org/wiki/Atom_(Web_standard)) from
provided Perl [Template Toolkit](http://template-toolkit.org/) templates.

While not many people use RSS readers these days, feeds can be used to
trigger an action with [Zapier](https://zapier.com), like uploading the new
comic to Facebook.

```json
{
    "Out": {
        "Comic::Out::Feed": {
            "outdir": "generated/web",
            "RSS": {
                "template": "path/to/rss.template"
            },
            "Atom": {
                "template": {
                    "English": "path/to/english/atom.template",
                    "Deutsch": "path/to/german/atom.template"
                },
                "max": 5,
                "outfile": "atom.xml"
            }
        }
    }
}
```

The above example configures two feeds, one in RSS and one in Atom format.
They share these options:

* `outdir` (mandatory): base output directory.

Each feed configuration can take these arguments:

* `template` (mandatory): either the template file, if all languages use the
  same template, or an object of languages to template path for different
  templates for each language. If all languages use the same template file,
  that file needs to either be language independent or check the `language`
  variable for language dependent output.

* `max`: how many comics to include at most in the feed. This value is
  passed to the template as `max`. Defaults to 10, meaning the feed will
  have the 10 latest comics.

* `outfile`: the file name of the output file. This will always be within the
  `outdir` output directory, plus a language specific directory (the
  language name in lower case), e.g., `generated/web/english/atom.xml` for
  the atom example above. Defaults to the lower-case feed name plus an
  `.xml` extension.

The `Comic::Out::Feed` module defines these variables for use in the template:

* `comics`: all comics, sorted from latest to oldest. All comic meta
  information is available. All comics are passed so that the template can
  decide which comics to include. This allows for language-independent
  templates at the price of higher template complexity if there are comics
  that don't exist in all languages.

* `language`: `Comic::Out::Feed` will populate the template for each language
  found; the currently processed language is in this variable.

* `max`: maximum number of feed items, as per configuration.

* `notFor`: a function that takes a comic, a location,  and a language and
  returns a Boolean indicating whether the given comic is for the given
  location and language. The location must be the same as in the comic's
  `published.where` metadata. This is used for comics that don't exist in
  all languages or comics that aren't published yet. It allows the template
  to skip these comics.

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

```json
{
    "Out": {
        "Comic::Out::FileCopy": {
            "outdir": "generated/web",
            "from-all": ["web/all", "misc/all"],
            "from-lanuage": "web/"
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

Generates a per-language HTML page with all published comics in chronological
order.

The configuration takes a template and an output file. You can pass a single
template for all languages, or one for each language. The output file is
always per-language.

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


## `Comic::Out::HtmlLink`

Generates a HTML reference ("see that other comic") from comic metadata.
This assume you use the `Comic::Out::HtmlComicPage` module as well.

This is only for linking to another of your comics; see below to  include a
hyperlink to any other web site.

This module does not take any configuration.

Actual linking is triggered by comic meta data within a `see` object. This
is language specific (link texts vary by language), so it needs a nested
language object with a link text as key and a `.svg` file as value.

```json
{
    "see": {
        "English": {
            "First reopening": "beergarden-reopened.svg"
        }
    }
}
```

Link targets are given as `.svg` source file names so that a referrer does
not depend on the actual title (and hence URL) of the linked comic. Also,
other forms of linking (e.g., to a page in a book) may not even have meta
data like an `.html` output file, but all comics do have a title.

This module adds a `htmllink` hash to each comic. The keys in that hash are
languages (with initial upper case letter), pointing to yet another hash.
That hash has a list of link text to (absolute) URL of the referred comic's
HTML page.

Link target `.svg` files can be given as (full or partial) paths or just
filenames; the latter is preferred unless you have the same filenames in
different directories.

Background: When comics are loaded, they remember their source file name.
This is usually relative to where you collected the `.svg` files. For
example, if your comics live in `comics/web/`, each collected comic will
have its source file starting with that path, and you could use e.g.,
`comics/web/some-comic.svg` as a reference. However, if your cron job
happens to just pass the full path to your comics directory (vs `cd`ing into
it and passing the relative path), your comics will have the full path
instead of just `comics/web/`. To work in both situations, the
`Comic::Out::HtmlLink` module looks first for an exact match, then it checks
all comics to see if their source filenames end in the link target. This is
a simple string comparison. It does not touch the file system and doesn't
allow relative paths like `../../other/directory/comic.svg`.


`Comic::Out::HtmlLink` is only for linking to another of your comics. To
include a hyperlink to any other web site just add it to your comic's
metadata and have the template do whatever it needs to do. For example, add
this in your comic:

```json
{
    "link": {
        "English": {
            "Click here for beer comics": "https://beercomics.com"
        }
    }
}
```

Then use something like this in the comic page template:

```template
[% FOREACH l IN comic.meta_data.link.$Language %]
<a href="[% l.value %]">[% l.key %]</a>
[% END %]
```


## `Comic::Out::HtmlComicPage`

This is the main output generator for web comics. It generates a HTML page
for each comic, plus an `index.html` overview page.

The configuration needs to be like this:

```json
{
    "Out": {
        "Comic::Out::HtmlComicPage": {
            "outdir": "generated/web",
            "template": {
                "English": "templ/comic-page.templ"
            }
        }
    }
}
```

The `outdir` specifies the main output directory; the actual files will be
generated underneath, in a directory for each language, with the HTML file
name derived from the comic's title.

The `template` refers to a Perl Toolkit template per language that will be
used to generate the page.

This module defines these variables in each comic, that the templates can
use:

* `htmlFile`: hash of language to file name of the generated HTML file,
  derived from the comic's title, e.g., for a comic with an English title of
  "Beer brewing" this could be `beer-brewing.html`.

* `href`: hash of the path to the comic's HTML file relative to the server
  root, per language, e.g., `comics/beer-brewing.html` for English.

* `url`: full URL to the HTML file for the comic in each language, e.g.,
  `https://beercomics.com/comics/beer-brewing.html` for English.

* `first`, `prev`, `next`, `last` are the `htmlFile` values of the first,
  previous, next, and last comic in that language, respectively.

* `isLatestPublished`: this variable is only defined on the last published
  comic in each language. The template can query this flag and change the
  page for the last published comic.

* `transcript`: object with languages as keys and texts of the comic as
  values.

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

* `siteComicsPath` path to comics, relative to the server root, with a
  trailing slash, e.g., `comics/`.

* `indexAdjust`: prefix for paths / URLs to other comics, so that navigation linking
  works in published an non-published comics.

* `root`: points to the server root, to be used to include CSS, static
  images, or JavaScript code.

The `index.html` file uses the same template as the regular comic pages.


## `Comic::Out::PngInkscape`

Generates a Portable Network Graphics (`.png`) file for from a Scalable
Vector Graphics (`.svg`) file by calling Inkscape.

You need to install png libraries on the operating system level, e.g., `brew
install libpng` on MacOS, or `sudo apt-get install libpng` on Ubuntu.

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

After writing, this generator defines these values in the comic for use in
templates or other generators:

* `pngName`: map of language to base name of the `.png` file, e.g.,
  `drink-beer.png`.

* `imageUrl`: map of language to complete URL of the `.png` file.

* `pngSize`: map of image size in bytes, per language.

* `height`: map of language to height of the image in pixels.

* `width`: map of language to width of the image in pixels.


## `Comic::Out::QrCode`

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


## `Comic::Out::Sitemap`

Generates a [sitemap](https://en.wikipedia.org/wiki/Sitemaps) per language.
Sitemaps can tell search engines which pages they should crawl.

```json
{
    "Out": {
        "Comic::Out::Sitemap": {
            "template": {
                "English": "templates/sitemap-en.xml",
                "Deutsch": "templates/sitemap-de.xml"
            },
            "outfile": {
                "Deutsch": "web/deutsch/sitemap.xml",
                "English": "web/english/sitemap.xml"
        }
    }
}
```

The module accepts these options:

* `template`: object of languages to Perl Toolkit template files to use for
  that language.

* `outfile`: object of languages to output files for the sitemaps in the
  respective languages.

The module makes these variables available in the template:

* `comics`: sorted (oldest to latest) list of published comics.

* `notFor`: code reference to a function to check whether a given comic
  should be included in the sitemap.

The generated file will always be placed in a per-language directory under
the configured `outdir`, named `sitemap.xml`.


## `Comic::Out::Sizemap`

Generates a size map showing all different overall sizes used in the comics.
This can help figuring out what size works nicely for one's style.

The size map is configured like this:

```json
{
    "Out": {
        "Comic::Out::Sizemap": {
            "template": "templates/sizemap.templ",
            "outfile": "generated/sizemap.html",
            "scale": 0.3,
            "published_color": "green",
            "unpublished_color": "blue"
        }
    }
}
```

The configuration parameters are:

* `template`: what Perl Template to use.

* `outfile`: to which file to write the size map.

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


## `Comic::Out::SvgPerLanguage`

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
            "outdir": "generated/svgs",
            "drop_layers": "Raw"
        }
    }
}
```

The `outdir` specifies where the generated `.svg` files should go; default
is `tmp/svg`. This module will create a directory per language in the given
output directory.

The optional `drop_layers` gives a single layer name or a list of layers
names to remove when saving the `svg` per language. Such layers must be
top-level layers (not inside other layers). They could be sketches or scans.
Removing them here makes for smaller `.svg` files which in turn take less
disk space and could speed up converting to other graphic formats like
`png`. If you do want to publish `.svg` files, it's probably also good to
remove that unneeded extra information and get faster downloads.


## `Comic::Out::Tags`

Collects tags from comics to provide tagging in comic pages, i.e., so that
comics can refer to other comics that use the same tags ("see also"). Use
tags so that readers can find all comics that feature a certain character,
or all that deal with certain ideas (e.g., all comics where people drink
ales).

You can include the tags (and links to other comics using a tag) in the
`HtmlComicPage` template, or you can use tag pages, or both.

A tag page is a HTML page listing to all comics that use the tag page's tag.
If a tag is used often, the comic's page could get too full trying to cram
too many links in. In that case, link to the tag page instead, which in turn
links to all comics using that tag.

Tags are case-sensitive, i.e., a comic tagged "Beer" will not refer to one
tagged "beer".

These kinds of comics are ignored for tag processing:

* Untitled comics (they are not considered to have any languages).

* Comics that are not yet published.

* Comics that are not published on the web.

The `Comic::Out::Tags` module is configured like this:

```json
{
    "Out": {
        "Comic::Out::Tags": {
            "collect": ["tags", "who"],
            "min-count": 3,
            "template": {
                "English": "path/to/english/template",
                "Deutsch": "path/to/german/template"
            },
            "outdir: "tags",
            "index": {
                "English": "path/to/english/index/template",
                "Deutsch": "path/to/german/index/template",
            }
        }
    }
}
```

The `collect` argument takes one or more names to use for tags from the
comic's metadata. It defaults to "tags" if not given.

'min-count' specifies how often a tag has to be used to be considered. That
way you can suppress tags pages and links when only two or three comics use
a tag. If not given, all tags are included.

The `template` is used for tag pages. It can either be a single file name,
if you want to use the same template for all languages, or an object where
each key is the language and points to the template file for that language.
If you don't configure a template, you don't get any tag pages.

The `outdir` is a folder relative to the server root where generated tag
pages will be placed. It defaults to `tags`. The `outdir` can be either a
single name or an object with language as keys and folder names as values,
like the `template`. If it's a single value, all languages will use that,
and since languages end up in different server roots, they will still have
separate tag files.

The `index` works like `template`, but it specifies the template for the
main tags overview page instead of the template for each tags page. That
page will be `index.html` in the confiugured `tags` folder. You can use it
for a tag cloud or just link to the individual tags pages. If no `index` is
configured, `Comic::Out::Tags` won't write an index page. This doesn't
disable the tags, you can still link from comics to tag pages, you just
don't have a nice tag overview page.


### Comic metadata

In the comics, the tags to collect must be found as objects with languages
referring to arrays of the actual tags, as top-level attributes in the
comic's metadata.

For example:

```json
"tags": {
    "English": ["beer", "brewing"]
},
"who": {
    "English": ["Paul", "Max"]
}
```

Passing "tags" for the "collect" parameter will pick the example values
above, but won't make the character names from `who` available as tags.


### Tags in the comic's page

`Comic::Out::Tags` defines these variables in each comic for use in a comic
page template:

* `tags` A hash of languages to hashes of comic titles to comic URLs
  (`href`) relative to the server root. Use this to add links from each
  comic to other comics that use the same tags.

  For example, a comic may get these tags:

  ```perl
  "tags" => {
      "English" => {
          "my tag" => {
              "some other comic" => "comics/other-comic.html",
              "yet another comic" => "comics/yet-another-comic.html",
          }
      }
  }
  ```

  A comic may include tags that appear in other comics, but no comic will
  include a tag referring to itself. For example, if comics A and B have a
  tag "beer", then the tags list in A will only refer to B and the tag list
  in B will only refer to A. That way you don't end up with links to the
  comic you just came from.

* `tags_page`: A object of language to URL. If there are too many comics
  sharing a tag, a link list in each comic's page may get unwieldy. You can
  instead link to the tag page, a page that lists all comics with that tag.
  The key in `tags_page` is the tag (e.g., "beer") and the value is the
  comic's url relative to the server root, e.g., "/comics/beer.html".

* `tag_count`: An object of language to tag to tag count, e.g., in English,
  tag "beer" was seen 10 times. This can be used to show only the top x
  tags, or to use different font sizes based on tag frequency.

* `tag_min` and `tag_max` (per language), how often the least often and how
  often the most often tag were used, as an object with the language as the
  key. In combination with `tag_count` this can be used to calculate the
  font size of items in a tag cloud.


### Tag pages

When you define a template, `Comic::Out::Tags` creates a html page for each
tag, using that template. These should be a list of links to comic pages
using a given tag.

`Comic::Out::Tags` defines these variables when processing the tag page
template:

* `tag`: The actual tag for which the page is.

* `language`: For which language the tags page is (starting with a lower
  case letter, e.g., "english").

* `comics`: A hash of title to URL (relative to the server root) for each
  comic that uses the tag.

* `root`: Relative path to the server root from the generated tag page,
  e.g., `../`. Code can add that to links from `comics` to avoid having to
  put a `/` for an absolute path in, which would work on a web server, but
  not when just looking at a local folder.

* `last_modified`: last modification date of the pages that have the current
  tag, in ISO 8601 format.

* `count`: How often that tag was used.

A simple tags page could look like this:

```html
<html>
<head>
    <title>All comics tagged [% tag %]</title>
</head>
<body>
<h1>All [% count %] comics tagged [% tag %]</h1>
<ul>
[% FOREACH c IN comics %]
    <li><a href="[% root %][% c.value %]">[% c.key %]</a></li>
[% END %]
</ul>
</body>
```


### Tag clouds

Both comic pages and tag pages (including the index page) can display tag
clouds. `Comic::Out::Tags` generates a `tag_rank` for each language with tag
names to a level indicator. The indicators will be `taglevel5` (most common
tags) to `taglevel1` (least frequently used tags). The pages can define CSS
rules for these names and then use the names when rendering the tags names.

For example, with this style sheet

```css
.taglevel5 { font-size: 150%; }
.taglevel4 { font-size: 125%; }
.taglevel3 { font-size: 100%; }
.taglevel2 { font-size: 80%; }
.taglevel1 { font-size: 70%; }
```

and this HTML page

```html
<p>
[% FOREACH t IN comic.tag_rank.$Language %]
    <a class="[% t.value %]" href="[% root %][% comic.all_tags_pages.$Language.${t.key} %]">[% t.key %]</a>
[% END %]
</p>
```

you'll get a tag cloud with links in different font sizes.
