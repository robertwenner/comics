# Comics

Lets you publish web comics in different languages with a single command.

When I started my beer and brewing themed web comic, I wanted to publish my
comics in both English (at [beercomics.com](https://beercomics.com)) and
German (at [biercomics.de](https://biercomics.de)). I used Inkscape for the
drawings because I wanted vector graphics for easy scaling (my first web
comic back in the day was in `.gif` format, and it looked like that in
print). Most comics work in both English and German, they can be translated.
So I put the languages in their respective layers, and show or hide one or
the other when exporting. This works manually, but gets tedious when you
have to remember to toggle layers and export to `.png` after each change.
(You could just put `.svg` files on the web, which saves you the "export as"
step but adds a "save as" step, so it's still the same work.)

Three strikes and you automate, as the Pragmatic Programmers said, so I
wrote a little Perl script to flip layers and export for me. Of course I
needed some `html` page around the comics, too, and wouldn't it be nice to
provide a transcript of the comic for search engine optimization and for
people with screen readers? Before I knew, my little Perl script was at 2500
lines and almost unmaintainable. Over the years I broke it up into more
manageable modules, added automated tests, and improved design and
documentation.


## Assumptions

That said, there are still a few basic assumptions on how things work:

- Everything is in the comic. The Inkscape `.svg` file is the "single source
  of truth". Everything needed for a comic is in that file, not in any other
  files, not in version control, not in a database of some sort, not in a
  microservice, and not in the blockchain. Most settings that are not
  specific to a particular comic are configured in global
  [settings](settings.md) and in the templates used to generate outputs (see
  below).

- Stuff needs to be in its place (layers and metadata). If everything is in
  the same file but needs to end up in different files per language, stuff
  needs to be somehow marked as belonging to a language (or none or all).
  This is done with Inkscape [layers](layers.md), and the layer names tell
  the Comics modules what to do with the layers (hide, show, get the
  transcript, and so on). Whatever doesn't go in a layer goes into the
  comic's [metadata](metadata.md).

- Generate everything. Since everything is in the comic's `.svg`, take that
  as input and generate whatever is needed: web pages, RSS feed, transcript,
  and so on. This is described in the [outputs chapter](outputs.md). Most of
  the generated output depends on the [templates](templates.md) you write.

- Have the computer help check. If a computer already processes each comic,
  have it also check for e.g., spelling errors. This is described in the
  [checks chapter](checks.md).

- Publish the comics. The assumption is that you have your own site and
  push a new comic e.g., every week. You don't need to run the web server on
  your own hardware, but have one you can access as you see fit. I don't
  recommend just tweeting or posting the comics to e.g., reddit. Being in
  charge of the server gives you more control. See the [upload modules
  chapter](upload.md) for details. You can let the modules in the [social
  media modules](social.md) chapter post your comic to social media.

The previous steps imply that it doesn't matter where you keep the comic
on your hard drive. They can be in one folder or in many (maybe nested)
folders. If you want to exclude comics from getting published on your web
page, for example, when they were exclusively for a book or magazine, that
information also needs to live in the [metadata](metadata.md). For
example, to allow for different publication locations, the metadata
supports a "published where" field. Generators may check for it and you
can query that in templates (see the [outputs chapter](outputs.md) for
details).


## Workflow

After installing the Perl modules, configure your [settings](settings.md)
for all comics. Then run the conversion through the Comics main module:

```perl
# perl
use strict;
use warnings;
use Comics;

Comics::generate('path/to/your/settings.json', "path/to/your/comics");
```

If you don't want to install the comic modules, you can also point the
script to them by adding a line after the other `use`s like this:

```perl
use lib "path/to/the/top-level/folder";
```

You can call that script e.g., from a Unix cron job to automatically publish
your latest comic.
