# Metadata

The Comic modules assume that the comic and all its data is in the Inkscape
`.svg` file, as opposed to e.g., having a separate file for the transcript
or even a database for additional information on a comic.

The metadata of a comic needs to be in the Description field in Inkscape. In
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
    "published": {
        "when": "2023-01-31",
        "where": "web"
    }
}
```

The `title` is most important: if a comic doesn't have a title for a given
language (or if the title is empty or contains only spaces), it doesn't
exist in that language. When code processes a comic, it always asks for the
comic's language by looking at the `title` metadata. This is a convenient
mechanism to keep a language out: When you want to support a new language,
you can already translate and add everything except the title, and only when
all comics are available in that language and you're ready to go, add the
titles.

Titles must be unique in their languages, i.e., you cannot have two comics
with the same title in the same language. It's ok to have the same comic
have the same title in different languages.

The `published.where` field tells where the comic is published. It allows
keeping all your comics in one folder, but still excluding some from your
web page, for example, if they were magazine contributions. "web" is a
special location indicating your web site. Besides that, you can use
any names you like. In particular, this should *not* be a domain name for a
web comic, as you'd probably need a different one for each language. Just
use something like "web" or "that cool magazine" or "my buddy's web page".
Output generators and templates may ignore comics not published in the
"right" location, in particular checking for "web".

The `published.when` date must be an [ISO
8601](https://en.wikipedia.org/wiki/ISO_8601) formatted date (without time),
that is a four digit year, a dash, a two digit month, another dash, and the
two digit day. For example, 2023-10-01 is October 1st in 2023. This date is
used to check if the comic is already published. Many output generators that
build your website will ignore a comic that is not yet published.

The example above shows the minimum meta data needed. Different
[check](checks.md) and [output](outputs.md) modules will use different
metadata fields; see the respective documentation on what they expect.

You are free to create additional metadata as needed, for example, to put a
link on the comic's web page. Generators ignore unknown metadata. However,
avoid names that have characters other than english letters, digits, and
underscores. Perl's [toolkit](templates.md) may get confused.
