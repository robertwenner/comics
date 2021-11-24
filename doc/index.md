# Comics

Lets you publish web comics in different languages with a single command.

When I started my beer and brewing themed web comic, I wanted to publish my
comics in both English (at [beercomics.com](https://beercomics.com)) and
German (at [biercomics.de](https://biercomics.de)). I used Inkscape for the
drawings because I wanted vector graphics for easy scaling (my first web
comic back in the day was in `.gif` format and it looked like that in
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

That said, there are still a few basic assumptions on how things work:

- Everything is in the comic. The Inkscape `.svg` file is the "single source
  of truth". Everything needed for a comic is in that file, not in other
  files, not in version control, not in a database of some sort, not in a
  micro service, and not in the block chain. Settings that are not specific
  to a particular comic are configured in global [settings](settings.md) and
  the templates used to generate outputs (see below).

- Stuff needs to be in its place (layer and metadata). If everything is in
  the same file but needs to end up in different files per language, stuff
  needs to be somehow marked as belonging to a language (or none or all).
  This is done with Inkscape layers, and the layer names tell the Comics
  modules what to do with the layers (hide, show, get the transcript, and so
  on). Whatever doesn't go in a layer goes into the comic's [metadata
  chapter](metadata.md).

- Generate everything. Since everything is in the comic's `.svg`, take that
  as input and generate whatever is needed: web pages, RSS feed, transcript,
  and so on. This is described in [outputs chapter](output.md) chapter.

- Have the computer help check. If a computer already processes each comic,
  have it also check for e.g., spelling errors. This is described in the
  [checks chapter](checks.md).

- Publish the comics. The assumption is that you have your own web site and
  push a new comic e.g., every week. You don't need to run the web server on
  your own hardware, but have one you can access as you see fit. I don't
  recommend just tweeting or posting the comics to e.g., reddit. Being in
  charge of the server gives you more control. See the [upload
  modules](upload.md) for details. You can still post to social media with
  the [social media modules](social.md).
