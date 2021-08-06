# Output

## Dependencies

Order matters in the configuration file; if you rely on the output from a
previous module, it needs to go before the module that requires the output.

For example, the Comic::Out::QrCode module will create QR codes for comic
pages and put the URL in the Comic. If the Comic::Out::HtmlComicPage module
wants to include the QR code in the page, it must run after (that means:
configured after) the Comic::Out::QrCode module.


## Output Organization

All generated files are placed under the directory configured as the main
output directory.

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


## Comic::Out::Feed

Generates website feeds (e.g., in [RSS](https://en.wikipedia.org/wiki/RSS)
or [Atom](https://en.wikipedia.org/wiki/Atom_(Web_standard) format) from
provided Perl [Template Toolkit](http://template-toolkit.org/) templates.

```json
{
    "Out": {
        "Feed": {
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

The Comic::Out::Feed module defines some variables for use in the template:

* `comics`: all comics, sorted from latest to oldest. All comic meta
  information is available. All comics are passed so that the template can
  decide which comics to include. This allows for language-independent
  templates at the price of higher template complexity if there are comics
  that don't exist in all languages.

* `language`: Comic::Out::Feed will populate the template for each language
  found; the currently processed language is in this variable.

* `max`: maximum number of feed items, as per configuration.

* `notFor`: a function that takes a comic and a language and returns a Boolean
  indicating whether the given comic is for the given language. This is used
  for comics that don't exist in all languages and allow the template to
  skip a comic that's not for the language being processed.

* `updated`: current time stamp, in [RFC 3339](https://tools.ietf.org/html/rfc3339)
  format (needed in Atom format).


## Comic::Out::HtmlComicPage

This is the main output generator for web comics. It generates a HTML page
for each comic, plus an `index.html` overview page.

The configuration needs to be like this:

```json
{
    "Out": {
        "HtmlComicPage": {
            "outdir": "generated/web",
            "Templates": {
                "English": "templ/comic-page.templ"
            }
        }
    }
}
```

The `outdir` specifies the main output directory; the actual files will be
generated underneath, in a directory for each language, with the HTML file
name derived from the comic's title.

The `index.html` file uses the same template as the regular comic pages.

When writing the `index.html`, the code sets a variable in the last published
comic in each language, `isLatestPublished`. The template can query to flag
and change the layout for the last published comic.
