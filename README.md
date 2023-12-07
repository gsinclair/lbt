# Description

`lua-based-templates` is a LuaLaTeX package to ease writing structured content (e.g.
exam, course material, worksheet, anything!) by allowing the user to define templates
using the Lua programming language. This means content can be written without the
usual LaTeX boilerplate.

Example...

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

* TeX archive: http://mirror.ctan.org/tex-archive/macros/luatex/...
* Package page: https://www.ctan.org/pkg/...

# Distributions

Not yet.

# Repository

https://github.com/gsinclair/lua-based-templates

## Files

* `lbt.tex`: 
* `lbt.lua`: The entry point to the Lua code of the package.
* `vendor/*`: Third-party libraries used in the implementation: penlight.
* `documentation.tex`: The LaTeX code to generate the documentation
  `lua-based-templates.pdf` from. Maybe.

# Documentation

* [User documentation as a PDF](http://example.com)

# Installation

## TeX Live

    tlmgr install lua-based-templates    # not yet

## Manually

    git clone git@github.com:gsinclair/lua-based-templates.git    # not yet
    cd lua-based-templates

### Using make (uses `kpsewhich -var-value TEXMFHOME` to find your local texmf directory)

    make install

    # What gets run:
    # 
    # rm -rf ~/Library/texmf/tex/luatex/lua-based-templates
    # mkdir -p ~/Library/texmf/tex/luatex/lua-based-templates
    # cp -f lbt.tex ~/Library/texmf/tex/luatex/lua-based-templates
    # cp -f lbt.sty ~/Library/texmf/tex/luatex/lua-based-templates
    # cp -f lbt.lua ~/Library/texmf/tex/luatex/lua-based-templates

## Compile the documentation:

    # I don't know about this yet. This is what CLOZE does.
    # 
    # lualatex --shell-escape documentation.tex
    # makeindex -s gglo.ist -o documentation.gls documentation.glo
    # makeindex -s gind.ist -o documentation.ind documentation.idx
    # lualatex --shell-escape documentation.tex
    # mv documentation.pdf cloze.pdf
    # mkdir -p $HOME/texmf/doc/luatex/cloze
    # cp -f cloze.pdf $HOME/texmf/doc/luatex/cloze

# Development -- placeholder text from CLOZE package

First delete the stable version installed by TeX Live. Because the
package `cloze` belongs to the collection `collection-latexextra`, the
option  `--force` must be used to delete the package.

    tlmgr remove --force cloze

## Deploying a new version

Update the version number in the file `cloze.dtx` on this locations:

### In the markup for the file `cloze.sty` (approximately at the line number 30)

    %<*package>
      [2020/05/20 v1.4 Package to typeset cloze worksheets or cloze tests]
    %<*package>

Add a changes entry (approximately at the line 90):

```latex
\changes{v1.4}{2020/05/20}{...}
```

### In the package documentation `documentation.tex` (approximately at the line number 125)

```latex
\date{v1.6~from 2020/06/30}
```

### In the markup for the file `cloze.lua` (approximately at the line number 1900)

```lua
if not modules then modules = { } end modules ['cloze'] = {
  version   = '1.4'
}
```

### Update the copyright year:

```
sed -i 's/(C) 2015-2023/(C) 2015-2021/g' cloze.ins
sed -i 's/(C) 2015-2023/(C) 2015-2021/g' cloze.dtx
```

### Command line tasks:

```
git tag v1.4
make
make ctan
```
