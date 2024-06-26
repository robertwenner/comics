# Templates

## Templating basics

The Comic modules use Perl's [Toolkit](http://template-toolkit.org/). A
template is a text where the variable parts are represented by special
markers. In Toolkit, they are enclosed by `[%` and `%]`. You can access
your comic metadata directly, and output modules will add more data for use
in templates.

Toolkit also supports

- [virtual methods](http://www.template-toolkit.org/docs/manual/VMethods.html)
  to work with lists and JSON objects
- [including](http://www.template-toolkit.org/docs/manual/Directives.html#section_INCLUDE)
  templates from multiple files
- converting data to [JSON](https://metacpan.org/pod/Template::Plugin::JSON)
- converting  data to [HTML](http://www.template-toolkit.org/docs/manual/Filters.html#section_html)


For example, you could use a simple template to generate an HTML page for
each comic:

```html
<html lang="en">
<head>
    <title>[% comic.meta_data.title.$Language %]</title>
<head>
<body>
    <h1>[% comic.meta_data.title.$Language %]</h1>
    <img src="[% comic.pngFile.$language %]" alt="[% comic.meta_data.description.$Language %]"/>
</body>
```

In the above example you see how you can access the comic's data:

- `comic` is the main variable passed from the output module; it represents
  the comic.

- `comic.meta_data` gives you access to the comic's [metadata](metadata.md),
  as you entered it in the comic.

- `$Language` is a variable set when processing the template; it has the
  current language (starting with an uppercase letter), e.g., "English", and
  `$language` is the same starting with a lowercase letter ("english").
  Templates (and Perl) are case-sensitive, and depending on what you use in
  your metadata, you need to use the corresponding variable here.

- `comic.pngFile` is the filename of the `.png` that an output generator
  like `Comic::Out::PngInkscape` generated. Check the [documentation of the
  output generators](outputs.md) to see what variables they define.


## Metadata from your comic

If you want to include metadata from your comic you can access it in
templates via `comic.meta_data`.


### For all languages

For example, sometimes your friends help with comics, and you want to give
them credit on the comic's web page. Because everything on a comic needs to
live in that comic's source file, you add it to the comic's metadata:

```json
{
    "contributors": [
        "My buddy"
    ]
}
```

Then the template can access and display that information:

```html
[% DEFAULT comic.meta_data.contributors = 0 %]
[% IF comic.meta_data.contributors && comic.meta_data.contributors.size %]
<p>With help from:
[% FOREACH c IN comic.meta_data.contributors %]
    [% c %]
[% END %].
</p>
[% END %]
```

The `DEFAULT` defines a default value for contributors and avoids a warning
about an undefined value if the comic has no contributor metadata. The `IF`
checks for that. In that case nothing is printed. If the comic does have
contributors metadata, the `FOREACH` loops over that list and prints their
names, in the above example "My buddy".


### By language

You can also use e.g., metadata per language in the comics page. For
example, you could have comics published in books or blogs. You could
save it in the comic's metadata like this:


```json
{
    "previouslyIn": {
        "English": [
            "some.blog.com",
            "The big book on my comics"
        ]
    }
}
```

In the template, you can display this information like so:

```html
[% DEFAULT comic.meta_data.previouslyIn.$Language = 0 %]
[% IF comic.meta_data.previouslyIn.$Language
   && comic.meta_data.previouslyIn.$Language.size > 0 %]
<p>
This comic was also published in
[% FOREACH p IN comic.meta_data.previouslyIn.$Language %]
    [% c %]
[% END %]
</p>
[% END %]
```

## Metadata added by the main Comic module

The main comic module defines these variables on each comic:

- `modified`: the last modification time of the comic's source file, in
  ISO8601 format (year hyphen month hyphen day, e.g., 2023-01-30).

- `rfc822pubDate` (only available in comics that have a published data in
  their metadata in `published.when`): comic's published date in RFC 822
  format, e.g., `Fri, 13 Jan 2023 00:00:00 -0600`.

- `rfc3339pubDate` (only available when the comic has a published date in
  its metadata): comic's published date in RFC 3339 format, e.g.,
  `2023-01-13T00:00:00-06:00`.

- `siteComicsPath`: path from the root of the web server to the directory of
  the comics; will have a trailing slash.

- `url`: The comic's URL, in `utf-8` encoding, per language.

- `urlEncoded`: The comic's URL, with the domain name puny-encoded and the
  path URL-encoded, per language.

- `htmlFile` the comic's HTML file, e.g., `my-comic.html`, per language.

- `href`: the path from the server root to the comic's HTML file, e.g.,
  `comics/my-comic.html`, per language.
