# Description

`lbt` stands for *Lua-Based Templates*.

It is a LuaLaTeX package to ease writing structured content (e.g.
exam, course material, worksheet, anything!) by allowing the user to define templates
using the Lua programming language. This means content can be written without the
usual LaTeX boilerplate.

# Status

`lbt` has been in private development and heavy use since about 2022. It first appeared on Github in May 2025. It is in active development but is absolutely **alpha** software: anything can change anytime.

Anybody who clones the respository should do a hard reset often, in case history has been rewritten. I will try to avoid rewriting published history, but I can't promise it will never happen. Use `git fetch origin` followed by `git reset --hard origin/main`.

# License

Copyright (C) 2015-2023 by Gavin Sinclair <gsinclair@gmail.com>
---------------------------------------------------------------
This work may be distributed and/or modified under the conditions of
the LaTeX Project Public License, either version 1.3 of this license
or (at your option) any later version.  The latest version of this
license is in:

  http://www.latex-project.org/lppl.txt

and version 1.3 or later is part of all distributions of LaTeX
version 2005/12/01 or later.

# CTAN

Not yet.

# Distributions

Not yet.

# Repository

https://github.com/gsinclair/lbt

## Files

* `lbt.sty`: The Latex package, which requires a lot of packages and creates the `lbt` environment and some supporting commands like `\lbtSettings` and `\lbtLoadTemplates`.
* `lbt-*.lua`: The Lua code that implements the `lbt` core and the inbuilt templates.
* `vendor/`: Third-party libraries used in the implementation: penlight and `debugger.lua`.
* `test/`: Some files that support testing of the project.
* `justfile`: Tasks that support development: edit in neovim, test, ...

### Other files

* `etc/`: Some scripts etc. that may have fallen out of date.
* `doc/`: Some documentation that is 1\% complete.
* `DOC-SCRATCH.md`: an old attempt at writing some documentation

# Documentation

* There will be some PDF documentation one day.

# Installation

## TeX Live

    tlmgr install lbt    # not available yet!

## Manually

    git clone https://github.com/gsinclair/lbt.git
    cd lbt
    make install

You can now put `\usepackage{lbt}` in your Latex code. The code below shows what `make install` does, just for interest.

    jobname = lbt
    texmf = $(shell kpsewhich -var-value TEXMFHOME)
    texmftex = $(texmf)/tex/luatex
    installdir = $(texmftex)/$(jobname)

	rm -rf $(installdir)
	mkdir -p $(installdir)
	cp -f $(jobname).sty $(installdir)
	cp -f *.lua $(installdir)
	cp -fr vendor $(installdir)
	texhash $(texmf)

