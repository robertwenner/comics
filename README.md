[![License: Artistic-2.0](https://img.shields.io/badge/License-Perl-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)

[![Build Status](https://travis-ci.org/robertwenner/comics.png?branch=master)](https://travis-ci.org/robertwenner/comics)


## What is this?

The Comic Perl module generates static web pages for web comics in
multiple languages from comics made in Inkscape.

I use it for my [https://beercomics.com](beercomics.com) and
[https://biercomics.de](biercomics.de) web comics.


## Dependencies

Use cpanminus and run `cpanm --installdeps --notest .` to install all dependencies.

Alternatively, install the dependencies from [CPAN](https://cpan.org); see
[lib/Comic.pm](the `use` statements in the beginning of the Comic.pm main
module) for dependencies.

You'll need [https://inkscape.org](Inkscape) in the `$PATH` to actually
export your comics to png.


### Installation

- perl Makefile.PL
- make
- make test
- sudo make install


## Copyright & License

Copyright (C) 2015 - 2018, Robert Wenner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
