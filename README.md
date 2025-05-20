# Description

LBT stands for *Lua-Based Templates*.

It is a package for LuaLatex.

It provides a way of writing content in a Latex document that has great advantages over ordinary Latex. In particular, it makes it easy to write Lua functions that you can call from your Latex code.

It is hard to convey what LBT does in a few sentences. Examples are necessary, but they are not prepared right now.

# Status

LBT has been in private development and heavy use since about 2022. It first appeared on Github in May 2025. It is in active development but is absolutely **alpha** software: anything can change anytime.

Anybody who clones the respository should do a hard reset often, in case history has been rewritten. I will try to avoid rewriting published history, but I can't promise it will never happen. Use `git fetch origin` followed by `git reset --hard origin/main`.

# Marketing pitch

Latex produces great documents, and has some good design behind it, but even someone like me who loves Latex must admit there are things about it that are awful. If you have repetitive content that you want to streamline, writing new commands in Tex is very unappealing. The commands you do write are part of a huge global soup with no namespacing. The syntax for ordinary things is kind of ugly, with backslashes and braces everywhere. If your document has fine structure, like an exam paper, then your code is likely very verbose, with an envrironment used to typeset every question, and every subquestion, etc.

For my own use, I wanted to prepare highly structured documents without running into the problems above, and without avoiding Latex. So I developed LBT. Here are some of the ways in which LBT makes authorship easier.
* All vertical content (paragraphs, lists, questions, tables, even a humble vspace) is specified using a command. Thus a snippet of LBT code for a classroom handout could look like this:

        BOX The following questions are to be done without a calculator.
        Q Solve the following for $x$, giving \emph{exact answers} where necessary.
        QQ $3x - 7 = 4$
        QQ $x^2 + 6x + 7 = 0$
        HINT Use the quadratic formula for the second question.
        VSPACE 5em
        TEXT We turn now to prime factorisation.
        Q Write, in index form, the prime factorisations of 24 and 42.
        Q Use the above factorisations to find the greatest common divisor of the two numbers.
        HINT Look at what prime factors 24 and 42 have in common, including repetitions.
        CLEARPAGE
        H3 Hints
        SHOWHINTS

* The commands above (`BOX`, `Q`, `QQ`, `VSPACE`, `TEXT`, `HINT`, `H3`, `CLEARPAGE`, `SHOWGINTS`) serve to highlight document structure, and clearly distinguish vertical from horizontal content. We do not use backslashes and braces for these important items, and they stand out.
  * `BOX`, `VSPACE`, `TEXT`, `H3` and `CLEARPAGE` come from the built-in template `lbt.Basic`, whose commands are always available to you.
  * `Q`, `QQ`, `HINT` and `SHOWHINTS` come from the built-in template `lb.Questions`. This is one of a dozen or so templates you can choose to use in each of your expansions.
* The commands above are not global variables. Each one is defined in a *template*, and you decide which templates you want to use and where. (All LBT code is contained inside an `lbt` environment, which provides isolation.)
* It is very easy to write your own commands and your own template. A template can be just a collection of commands, or it can be a document structure. For example, the built-in template `lbt.Article` typesets an entire article, complete with heading, author, abstract, and so on. It does layout *and* it provides extra commands to help you.
* The example code above is concise: `Q` and `QQ` do a good job of typesetting questions and subquestions without needing to explicitly open and close environments.

Further, commands can have multiple arguments and optional arguments:

    ITEMIZE .o compact
    :: Bach's \emph{St Matthew Passion}
    :: Beethoven's \emph{Missa Solemnis}
    :: Part's \emph{Passio}

The `.o` signals a comma-separated list of *optional arguments*, making it easy to write flexible commands. Using ` :: ` to separate arguments spreads the text out and makes the structure clear, improving readability. Where we *do* have backslashes-and-braces is with commands like `\emph{...}`, which operate on horizontal content rather than vertical structure. Once again, the distinction is clear to the eye.

There is *so much more* to LBT, both in terms of core features and provided commands and templates.

When you write documents using LBT, you are inside a Latex file, embracing the spirit of Latex but changing the surface appearance, and embracing what LuaLatex provides: the ability to use a real programming language to enhance Latex.

I have written hundreds of pages of content using LBT over the last few years: course notes, question sets, other handouts, articles, a photo gallery, a timetable, and more.

# CTAN and distributions

Being **alpha** software undergoing rapid change, it is not yet available on CTAN, and it certainly not in any distributions.

# Repository

https://github.com/gsinclair/lbt

# Files

* `lbt.sty`: The Latex package, which requires a lot of packages and creates the `lbt` environment and some supporting commands like `\lbtSettings` and `\lbtLoadTemplates`.
* `lbt-*.lua`: The Lua code that implements the `lbt` core and the inbuilt templates.
* `vendor/`: Third-party libraries used in the implementation: penlight and `debugger.lua`.
* `test/`: Some files that support testing of the project.
* `justfile`: Tasks that support development: edit in neovim, test, ...

## Other files

* `etc/`: Some scripts etc. that may have fallen out of date.
* `etc/media.tgz`: a tarball of the original project `gsContent`, of which `lbt` is a rewrite.
* `doc/`: Some documentation that is 1\% complete.
* `DOC-SCRATCH.md`: an old attempt at writing some documentation

# Documentation

* There will be some PDF documentation one day.

# Installation

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

## TeX Live (not available yet!)

    tlmgr install lbt    # one day...

# Notes about testing

Here is how testing goes. You run `just test` from the `test` directory. That issues a command to build the file `general-test-document.tex`. But that file rarely gets built! You see, one of the Lua files that gets loaded by `\usepackage{lbt}` is `lbt-8-test.lua`. This is loaded every time, whether you want to run tests or not. Whether you actually run tests is determined by the final line `RUN_TESTS(n)`, where you pass `n` as 0 to skip tests and get on with document building, or 1 to run tests and exit, or 2 to run tests and continue. This is set to 0 99\% of the time. Most "testing" is done using real documents that live outside the repository, or a file called `SimpleTest.tex`, also outside the repository. I only run the test suite occasionally, and it has pretty low coverage of the project. But it serves its purpose. Many core features are thoroughly tested in there, and it was those tests that helped to develop them in the first place.

So `general-test-document.tex` really just exists as a trigger to run the tests.

Other things in `test` are two test templates (used in the test suite) and some other ad hoc test files that don't get used or run very often, if at all. A future cleanup will surely see to some of them.

# Roadmap to 1.0

After a lot of active development, the feature set is converging and it is starting to seem possible that a 1.0 release could occur. Right now (initial upload to GitHub, May 2025) I'd put the code at "0.4", reflecting the number of overhauls it has had along the way.

Here are a few things that need to improve in the code before 1.0:
* validation of opargs and kwargs
* correct implementation of all error messages
  * each error message has a number, but many are haphazard and most error messages introduced recently have been generic
* implementation of all planned templates
* documentation
* rationalisation of log output: it is too verbose at the moment

There will be releases in time: 0.4, 0.5, ... and a Changelog to keep track.

# Note to self

Some of the code and makefile and readme structure came from the Latex `cloze` package.

# License

Copyright (C) 2025 by Gavin Sinclair.

This work may be distributed and/or modified under the conditions of
the LaTeX Project Public License, either version 1.3 of this license
or (at your option) any later version.  The latest version of this
license is in:

  http://www.latex-project.org/lppl.txt

and version 1.3 or later is part of all distributions of LaTeX
version 2005/12/01 or later.
