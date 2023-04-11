[![License: Artistic-2.0](https://img.shields.io/badge/License-Perl-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)
[![Build Status](https://travis-ci.org/robertwenner/comics.svg?branch=master)](https://travis-ci.org/robertwenner/comics)
[![Coverage Status](https://coveralls.io/repos/github/robertwenner/comics/badge.svg?branch=master)](https://coveralls.io/github/robertwenner/comics?branch=master)


# Comics

Lets you publish web comics in different languages with a single command.

The Comic Perl module generates static web pages for web comics in multiple
languages from comics made in Inkscape. I use it for
[beercomics.com](https://beercomics.com) and
[biercomics.de](https://biercomics.de).

Please note that it's just suited to my current needs. It evolved from a
Perl script, and still has a bunch of hard-coded names and assumptions.
I'm slowly cleaning those up as I'm splitting the code into multiple
modules, and then I'll also add more features. That said, it's a bit slow as
the code works for me (no urgent need), so don't be surprised to see months
without commits. The interfaces are also not stable, in particular
configuration file entries may change.


## Dependencies

Use cpanminus and run `cpanm --installdeps --notest .` to install all
dependencies, and hope that it works. Or see [the makefile](Makefile.PL).

You'll need [Inkscape](https://inkscape.org) in the `$PATH` to actually
export your comics to `png`.

You also need `Imager::File::PNG`, which in turn depends on `libpng-dev`.

`optipng` is recommended to shrink exported png files.

For spell checking, you need `ASpell` or `Hunspell` with the corresponding
development libraries. I had a hard time with Hunspell and UTF8, so I prefer
ASpell and its libraries `libaspell-dev` plus dictionaries for the languages
you want to use (e.g., `aspell-de`, `aspell-en`, or `aspell-es`).

For uploading via rsync, you need to install the `rsync` command.

**MacOS users:*  if you are using [brew](https://brew.sh), just run `brew
bundle` to install the dependencies.


## Installation

```bash
perl Makefile.PL
make
make test       # optional, may need Perl test modules
sudo make install   # optional, you can also refer to the lib/ folder here
```

## Documentation

See the [comic author / artist documentation](doc/index.md) or the Perl
[developer documentation](doc/developers.md).


## Copyright & License

Copyright 2015 - 2023, Robert Wenner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
