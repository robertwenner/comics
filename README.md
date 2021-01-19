[![License: Artistic-2.0](https://img.shields.io/badge/License-Perl-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)
[![Build Status](https://travis-ci.org/robertwenner/comics.svg?branch=master)](https://travis-ci.org/robertwenner/comics)
[![Coverage Status](https://coveralls.io/repos/github/robertwenner/comics/badge.svg?branch=master)](https://coveralls.io/github/robertwenner/comics?branch=master)

## What is this?

The Comic Perl module generates static web pages for web comics in
multiple languages from comics made in Inkscape.

I use it for my [beercomics.com](https://beercomics.com) and
[biercomics.de](https://biercomics.de) web comics.

Please note that it's just suited to my current needs. It evolved from a
Perl script, and still has a bunch of hard-coded names and assumptions.
I'm slowly cleaning those up as I'm splitting the code into multiple
modules, and then I'll also add more features. That said, it's a bit slow as
the code works for me (no urgent need), so don't be surprised to see months
without commits.

## Dependencies

Use cpanminus and run `cpanm --installdeps --notest .` to install all
dependencies, and hope that it works.

It probably won't, so install the dependencies from [CPAN](https://cpan.org); see
[the `use` statements in the beginning of the Comic.pm main module](lib/Comic.pm)
for dependencies. You'll also need to install test modules, in particular
Test::Class and Test::Perl::Critic, if you want to run the tests.

You'll need [Inkscape](https://inkscape.org) in the `$PATH` to actually
export your comics to png.

You also need Imager::File::PNG, which in turn depends on `libpng-dev`
and `optipng`. For spell checking, you need ASpell dev libraries
(`libaspell-dev`) plus dictionaries for languages you want to use.


### Installation

- perl Makefile.PL
- make
- make test
- sudo make install


## Copyright & License

Copyright (C) 2015 - 2020, Robert Wenner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
