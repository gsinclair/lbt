# LBT development notes

This is not an appending journal. It is a live document with a place to design and/or document features. Ultimately the information either withers or ends up in proper documentation.


## Worksheet groups (was: chapter abbreviations)

I think I will reintroduce worksheet groups for WS0 and WS1. It is implemented for WS1, I think. And I think I'll introduce worksheet numbering to WS0. So basically, WS1 will stop being special in this regard, but I will format it differently (just because I can).

I will consider a META flag NUMBERED (set to true/false -- default true).


## Set draft mode

The current way to do it is `\lbtDraftModeOn`.

But what I really want to do is enable `\usepackage[(no)draft]{lbt}`. Happy to keep the on/off commands as well.


## Some notes from a recent commit

These help to guide a code review that needs to happen soon!

    * lbt.fn.pc.content_list(pc, key) -->
      lbt.fn.pc.content_list_or_nil(pc, key)

    * same with content dictionary

    * lbt.util.content_dictionary_or_{nil,error}

      - I kind of have duplicate functionality in fn and util. Reason being:
        fn is for internal use; util is for use within template code. A code
        review will help to sort this out if necessary. In particular,
        consider how errors from template code are reported. I am
        inconsistent at the moment. Should I call lbt.err.xyz? Should I call
        lbt.util.template_error(...)? Or should I return { error = ... }.

    * lbt.sty: require package 'tabularray'. I am going all in on this one.
      It's 2024 for goodness sake. Anyway, still to come: TABLE command in
      lbt.Basic.


## Options argument

Currently for an enumerated list we can do

    ENUMERATE [topsep=0pt] :: item1 :: item2 :: item3

The first argument is an (optional) "options" argument. Unpacking it is supported by `lbt.util.extract_option_argument`. Some things to consider:

* Should it be "option_argument" or "options_argument"?

* The caller should be able to specify the position in which it occurs. In the enumeration example above, it occurs (if at all) in position 1, and that would be fairly normal. However, it is possible that options might appear in position 2, such as (not currently supported) `BEGIN listings :: [python]`.

* Indicating an options argument with `[...]` seems like it could be fragile. No better idea immediately comes to mind, but... `[opt:...]` ?

* Put some thought into how options are specified and separated. My first thought is that ideally they must be set tight (no spaces) like `key=value key=value key=value`, and then commas between then can be optional. This scheme appears somewhere else (I forget where) and consistency would be good.


## Separate lists and dictionaries in parsed content object

I've had this idea for a while and just noted it in a TODO in util.

    -- TODO I think it would be good for content lists and dictionaries to go
    -- in separate slots. So we would have pc.META and pc.list.BODY and
    -- pc.dict.INTRO, for example.

This would allow us to have the same name in both camps (not the best idea) and have better error messages when something doesn't exist (that's better).

## Some aids to debugging a document

* Place an 'x' at the beginning of a command name to cause it to be ignored. For instance, replace TEXT with xTEXT.

* Have a control signal to stop reading content for this expansion, like `CTRL stop-reading` or something.

* Perhaps easiest, simply recognise Latex comment '%' at the beginning of the line!


## Some renaming of concepts

I have decided that "tokens" will be renamed "commands". That applies to the objects themselves and to the functions that implement them and the functions that work with them.

The documentation will explain why they are called commands, and note the difference in programming languages between commands and functions, and note that LBT "macros" act as functions, but they are closely tied to Latex macros so the name "macro" is used.

In template files we will then have:

    return {
        ...
        commands = c,
        arguments = a,
        styles = s,
        macros = m
    }

I will be pleased when this change is made.


## Macros such as defint and myvec

The old GSC code had wonderful Lua-implemented macros for (in)definite integrals and vectors. I made heavy use of them. They were implemented along these lines:

    # Lua
    GSC.macros.myvec = function(text)
      ...
    end

    # Latex
    \newcommand{\myvec}[1]{\lua{GSC.macros.myvec{'#1'}}}

This was fine when GSC was a single-document concern and I could tailor it to do whatever I want. But now it is generalising and I need to think about whether and how to achieve this desirable functionality without assuming every user wants it and without trampling on the global namespace.

One solution is as follows. Say I have a content template called `Math`. It defines some tokens like ALIGN and whatever else. And perhaps it can define some macros like `indefint` and `defint` and `myvec`. These are defined using `lbt.api.define_macro('Math', 'defint', function(text) ... end)`. Or are they declared in the template table? (Yeah, probably.)

OK, so how are they used? For a start, they can only be used in a LBT environment. The author might write

    \begin{lbt}
        [@META]
            TEMPLATE   lbt.WS0
            SOURCES    Math
            MACROS     defint,indefint,myvec
        [+BODY]
            TEXT Consider the vector \myvec{PQ} where ...
            Q Evaluate \indefint{e^{2x},dx}.
    \end{lbt}

So what is happening here?

By declaring `MACROS  defint,indefint,myvec`, the three Latex commands `\defint` etc. are being created *only in this expansion* (because of `\(begin|end)group`) and can be freely used. The definition, behind the scenes, is simple:

    \newcommand{\myvec}[1]{\luaexec{lbt.api.run_macro('Math', 'myvec', '#1')}}

This seems like a pretty good design and not hard to implement.

An author could decide to use `\myvec` freely in the document with a command:

    \lbtMacroDefine{\myvec}{Math}{myvec}
    \lbtMacroDefine{\myvec}{Math.myvec}      {better if it's possible}
    \lbtMacroDefine{\myvec=Math.myvec}       {best?}
    \lbtMacroDefine{\myvec=lbt.Math:vector}          {even better?}

So what does this mean for an author writing their own templates? It means it's not hard to squeeze in some extra Lua functions to define macros, and it's not too hard to access them. They are already invested in saving template files on their computer and letting LBT know where to look. That hard work is done, and now they can write Lua functions without thinking about how to manage them.

As a first pass, I think I will skip the `MACROS` bit and go straight to `\lbtMacroDefine`. It's simpler and kind of reasonable and might be all I need.


## Error messages

Error messages are all coded in `lbt.err`, one function per error. An example is `lbt.err.E203_no_META_defined`. Each one calls the local function `E`, which prints the error message to screen and logfile and debug file, then exists the process.

There are a couple of things to work on:
 - Take a good look at all error numbers. Some are assigned fairly randomly, just waiting for a cleanup. Not all are implemented.
   - The idea is for the first digit to be meaningful. Like E1xx is for internal errors (that just shouldn't happen), E2xx is for content-parsing errors, etc. This needs some careful thought and then implementation.
 - Make the error message clearer on the screen. Error messages in Latex output are a bit of a pain to read, so jazz it up a bit with more vertical whitespace and so on.


## Simpler invokation for content-only templates

The word "template" is a good choice for a key aspect of what LBT does, like formatting a worksheet or exam. But what if I had a normal article and I wanted to include a limerick? I might define a template `Poetry` with tokens `LIMERICK` and `SONNET` and goodness knows what else, then my Latex code might look like:

    \documentclass[article]
    ...
    \begin{document}
    ...
    \begin{lbt}
      [@META]
        TEMPLATE lbt.Basic
        SOURCES  Poetry
      [+BODY]
        LIMERICK There once was a pirate named Bates
         » ::    Who rolled round the deck on his skates
         » ::    He fell on his cutlass
         » ::    Which rendered him nutlass
         » ::    And practically useless on dates
    \end{lbt}
    ...
    \end{document}

See what happened there? I used the built-in, and elementary, template `lbt.Basic` just so I could use LBT at all. What I really want is access to the `LIMERICK` token. There is no structural layout like a worksheet or exam; there is just an inline poem typeset by a function `Poetry.LIMERICK`, which knows how to indent the two shorter lines and how to keep all five lines together on a page.

`Exam` is a structural template that has a titlepage and header and footer and some boilerplate between sections, and so on. `Poetry` is nothing but a collection of functions. It is a content-only template. You could write an English exam using `Exam` (or, more likely, a specific one you developed) and include `Poetry` as one of the `SOURCES`.

LBT exists to dramatically reduce boilerplate. But there is plenty of it in the short example above. Fortunately, it is easy to design a way to cut it down.

    \begin{lbtBasic}{Poetry}
      LIMERICK There once was a pirate named Bates
       » ::    Who rolled round the deck on his skates
       » ::    He fell on his cutlass
       » ::    Which rendered him nutlass
       » ::    And practically useless on dates
    \end{lbtBasic}


## Logging (consolidate logfile and debugfile)

It is important to have good logging so that future content authors can see where the processing was up to when an error occurs. And debugging information is good for development. But having a logfile and a dbgfile is a bit confusing -- what goes where? It would be good to have a considered and consolidated approach. I think there can be *levels* and *channels*.

Levels:

    1: ERROR
    2: WARN
    3: INFO
    4: DEBUG   [TRACE?]

A logfile message could be written with `lbt.log(3, 'Expanded line %s', line)`, which includes the level and a formatted message.

The debug level can be general but should be fairly well considered: what extra information would be good to see when filing a bug report, say.

For active development, extra debugging is needed, which is ephemeral. This is where channels can come in. Say I am working on registers. I could call `lbt.log('reg', 'Current register values: %s', pp(rv))`. Here the first argument is not 1-4 as usual, but it is a message to be filed on the `reg` channel. It would appear in the log file as `[reg] ...` or something. Perhaps it would *also* go in a file `lbt-reg.txt`.

The author could configure logging with `\lbtLog{3,reg}` to get all of 1-3 *and* the `reg` channel.

In fact, channels are good for some general debugging information, like:
 - #read           reading contents between 'begin' and 'end' lbt
 - #parse          turning it into parsed content
 - #emit           turning it into Latex

It would be useful to be able to turn each of those on and off.

A general #dev channel could cover all active development.

User interface:

    \lbtLog{1,2,3,emit,dev}
    ...
    \lbtLog{-dev}               [remove the dev channel; keep rest the same]
                                [not implemented at first - see if it's needed]

    \lbtLog{all}                [special keyword that enables every channel]

    \begin{lbt}
        !DEBUG                  [sets all channels for this expansion]
        ...
    \end{lbt}

This might see the end of `lbtDebugMode(On|Off)`.


## Documentation of styles

When implementing styles I was at one point going to write `lbt.api.style(key)` as a way for token-expansion functions to obtain style information. That changed to the use of a style-resolving higher-order function. But I ended up writing a lot of stuff that I thought could be used as documentation. That needed to move elsewhere, and that place is here.

    -- lbt.api.style(key)
    --
    -- A template has styles built in to it. For example, in a Questions template
    -- the default vspace before a question might be 12pt. And so if the template
    -- object is `t` then we would have `t.styles['vspace'] == '12pt'`.
    --
    -- A template has styles built in to it. For example, in a Questions template
    -- we might have:
    --
    --   a.Q = 1
    --   s.Q = { vspace = '12pt', color = 'RoyalBlue' }
    --   f.Q = function(n, args)
    --     local vsp = lbt.api.style('Q.vspace')
    --     local col = lbt.api.style('Q.color')
    --     local q   = lbt.api.counter_inc('q')
    --     return F([[{\color{%s}\bfseries Question~%d \enspace %s \par}]],
    --              vsp, col, q, args[1])
    --   end
    --
    -- This demonstrates _setting_ the styles with `s.Q = { ... }` and _getting_
    -- them with `lbt.api.style(...)`. Note that the function for getting them
    -- is intentionally short because it will be called upon often. It can be
    -- localised within a template file via `local style = lbt.api.style` if
    -- desired.
    --
    -- So what happens here? Well, when the template is registered, the style
    -- information is a dictionary:
    --
    --   t.styles == { Q = { vspace = '12pt', ...}, ...}
    --
    -- Upon registration this is collapsed so that we have:
    --
    --   t.styles == { 'Q.vspace' = '12pt', 'Q.color' = 'RoaylBlue',
    --                 'MC.alphabet' = 'Roman', ... }
    --
    -- Another style for the `MC` token was included to show how many tokens
    -- live side-by-side in this collapsed style dictionary.
    --
    -- But those are the styles for only one template. An expansion typically
    -- involves several templates, so to resolve a style we (in principle) have to
    -- look in several places. Further, there can be document-wide overrides and
    -- expansion-wide overrides, as seen in the example below.
    --
    --   \lbtStyle{Q.vspace 12pt :: MC.alphabet :: arabic }
    --
    --   \begin{lbt}
    --     [@META]
    --       TEMPLATE    Exam
    --       STYLE       Q.vspace 30pt :: Q.color gray :: MC.alphabet roman
    --     [+BODY]
    --       TEXT  You have 30 minutes.
    --       Q  Evaluate:
    --       QQ $2+2$
    --       QQ $\exp(i\pi)$
    --   \end{lbt}
    --
    -- To resolve styles at expansion time, there are three good options:
    --
    --  * Form a consolidated dictionary of all styles, respecting overrides.
    --    Store this globally or pass it around.
    --
    --  * Look in all required places, in order, until the style is found,
    --    and then cache the result for future lookups. This means some information
    --    needs to be global.
    --
    --  * Create a style resolver and pass that around. This keeps information
    --    private in a closure (like we do with a token resolver) but it means
    --    token functions having a third parameter.
    --
    -- We take the third option. I initially baulked at token functions taking
    -- another parameter, but have now gone down that route because Lua allows you
    -- to write only as many parameters as you need. It's loose but convenient.
    -- For example, in a Questions template:
    --
    --   f.Q = function(n, args, s)
    --     local vsp, col = s.get('Q.vspace Q.color')
    --     ...
    --   end
    --
    --   f.MC = function(n, args)
    --     ...
    --   end
    --
    -- In particular, look at the way style access is implemented, using one long
    -- string to look up many values. This helps keep token functions concise.
    --
    -- Amazingly, I have written documentation for a function where the design
    -- has changed from the top of the function to the bottom. In fact, the
    -- function no longer exists!! Anyway, it is staying here for this commit
    -- and will be removed later, becuase the text above is a useful basis for
    -- documentation.
    --
    lbt.api.style = function (key)
      -- TODO remove!
    end


## Registers

STOre a value in a named register and access it later. Each one has a TTL so that it doesn't stay around polluting the namespace for long. This solves a real problem when it comes to long content. It simulates a local variable.

The following code builds up the quadratic formula bit by bit. While it is a toy example, it accurately demonstrates a key value of the register feature: giving names to pieces of information that can then be used in a readable way, such that paragraphs of text can be clear, without containing expansive low-level typesetting.

Note that the $ in the name shows that it is mathematical text, meaning it will be silently wrapped in `\ensuremath`

    STO $Delta :: 4 :: b^2 - 4ac
    STO $Num   :: 4 :: -b \pm \sqrt{◊Delta}
    STO $Den   :: 4 :: 2a
    STO $QF    :: 1000 :: x = \frac{◊Num}{◊Den}

The building blocks `Delta`, `Num` and `Den` have a short life: they are being used to build `QF`. But `QF` has a long life as it will see a lot of use in whatever section we are writing. This way, if some text further down refers to `Num` it will be either a new value or an error (because the author forgot to redefine it). It will *not* silently refer to `-b \pm \sqrt{◊Delta}`.

The author has used this register feature most commonly to typeset complicated integrals. Consider an exam question where variants of the same integral appear in multiple places, say with different bounds. Now the following is possible.

    STO $Exp    :: 5 :: \frac{x^{2^n}}{1 - x^{2^{n+1}} }
    STO $A      :: 5 :: \frac{1}{1 - x^{2^{n}}}
    STO $B      :: 5 :: \frac{1}{1 - x^{2^{n+1}} }
    STO $C      :: 5 :: \frac{1}{1 - x}
    STO $D      :: 5 :: \frac{1}{1 - x^{2^{N+1}} }
    STO $SumInf :: 5 :: \sum_{n=0}^\infty
    STO $SumN   :: 5 :: \sum_{n=0}^N
    STO $Final  :: 5 :: ◊SumInf \frac{1}{2021^{2^n} - 2021^{-2^n}}

    Q*
    QQ 2 :: Noting that $a^{b^c}$ means $a^{(b^c)}$, show that
     » \[ ◊Exp = ◊A - ◊B. \]
    QQ 1 :: Hence show \[ ◊SumN ◊Exp = ◊C - ◊D. \]
    QQ 1 :: Let $x$ be a real number with $-1 < x < 1$. Show that
     » \[ ◊SumInf ◊Exp = \frac{x}{1-x} \]
     » by considering the behaviour of $◊SumN\dots$ as $N->\infty$.
    QQ 2 :: Hence find \[ $Final. \]

The result is a nice separation of the gnarlier mathematical content from the ordinary question text. It does not mean that the typesetting code is easy to *read*, but it does make it easier to write and easier to maintain.

Another place where we might like to separate concerns is footnotes. Borrowing an example from https://www.bibliography.com/apa/using-footnotes-in-apa/, we could write:

    STO fn1 :: 1 :: See Burquest (2010), especially chapter 5, for more
    » information on this journalist's theory.
    STO fn2 :: 1 :: From the chapter ``Theories of Photojournalism'', W.
    » Jones and R. Smith, 2010, Photojournalism, 21, p.~122. Copyright 2007
    » by Copyright Holder. Reprinted with permission.

    Journalists examined---over several years\footnote{◊fn1}---the ancient
    tools used in photojournalism.\footnote{◊fn2}

Now the typesetting source code for the paragraph itself is easy to read. The messy details are out of the way, but are well within reach if maintenance is needed, and they only stick around in memory as long as they are needed.

### About the design

The instruction `STO` was inspired by high school calculators of the author's acquaintance, which use exactly that instruction to store a value in the chosen memory (A--F). It is suitable for use in LBT because it is short, easily remembered once learned, and is unlikely to clash with the name of a token an author might want to use.

The lozenge ◊ is taken from Scribble, a document-preparation tool associated with the Racket programming language. The idea is to use a non-ASCII symbol so that is easy to spot and is not likely to clash with any symbols an author wants to use. But what if an author wants to use a lozenge? No problem. `◊ABC` wll only expand to the contents of a register if `ABC` is actually the name of a currently-defined register. Otherwise, it will simply render as it is written.

Should the author be warned (via the logfile, say) if `◊ABC` is encountered but not resolved? Perhaps. But even if they are not, they will surely notice that the PDF output does not match their intention, and the lozenge will draw attention to itself?

But how do you type the lozenge into your source code? That's up to you. It's not trivial, to be sure, but this drawback is greatly outweighed by the benefits of using it. You can copy the symbol from a website: unicode "Lozenge" with code 25CA. For what it's worth, I have an insert-mode mapping in my editor (neovim): `inoremap ,, ◊`.

The time-to-live ticks down for every token that is processed. `STO` does not count.

When a `STO` definition includes a register reference, it is expanded immediately. Like lines 2 and 4 of the following.

    STO $Delta :: 4 :: b^2 - 4ac
    STO $Num   :: 4 :: -b \pm \sqrt{◊Delta}
    STO $Den   :: 4 :: 2a
    STO $QF    :: 1000 :: x = \frac{◊Num}{◊Den}

`◊QF` is long-lived. It does not matter that it relies on the short-lived `◊Num` and `◊Den` for its definition.

When a line of parsed content is expanded into Latex, it is first scanned for any registers, and they are replaced with their value. There is no need for recursion as register values will not contain register references: those have already been expanded.

A line of parsed content may *be* a register definition, with the "token" (it's really a built-in) `STO` and the arguments `{'$Den', '4', '2a'}`. Now say the current `statement_number` (a local variable in the expansion function) is 39. Then the mapping `Den -> { value = '\ensuremath{2a}', exp = 43 }` is inserted into the Map at `lbt.var.registers`.

We don't bother to clear out expired registers; we just check whether they are expired before allowing their expansion to take place.

*Although*, I am thinking of including a builtin token provisionally called CTRL, which allows you to pass through "control" messages. Some examples might be:

    CTRL clear-registers
    CTRL ignore-on
    ...
    ...     {many lines of content to be ignored for now}
    ...
    CTRL ignore-off
    CTRL unknown-register-error    [default?]
    CTRL unknown-register-warn
    CTRL log "some message..."
    CTRL log-state                 [for debugging]
    CTRL dump-state filename.txt

This would be a good way to give the user the ability to exercise some control over things without greatly expanding the number of tokens used.


## Simplemath improvements via lpeg

Hopefully I can use lpeg to recognise 'words' without needing spaces. For example, 'int_0^infty frac 1 x \, dx' should be able to pick up the 'int' and the 'infty'.


## Major updates: lpeg parsing, option and keyword args, flexible linebreaks

(June 2024) I have been running some lpeg tests in lbt-7-test.lua to get the hang of it, and it is good. Now I have made a new branch 'lpeg-parsing' to implement the following:
 * Each command will automatically support option arguments and keyword arguments, in addition to the normal positional arguments. For example:
```
     TABLE .o float, pos=htbp
       :: (colspec) llX
       :: (rows[1]) font=bold
       :: (hlines) 1
       :: (caption) Employees at at June 2023
       :: (label) table: employees june 2023
       :: Name & Years of service & Division
       :: Terry & 11 & Finance
       :: Joan & 7 & Marketing
       ::    ...
```
 * Flexible newlines in commands, with little or no need for ». This is demonstrated above, with `::` starting each line. You can also end a line with `::`. Therefore, » should almost never be necessary.
 * lpeg parsing of individual commands into an intermediate structure.
 * command functions have signature like `c.TABLE = function(n, args, o, kw)`.
 * Maybe, lpeg-assisted parsing of the whole lbt document. Perhaps one line at a time to better isolate errors. We'll see.
 * `[[ ... ]]` for verbatim argument text. Good for code listing. For example:
```
      MINTED .o lineno=true :: python :: [[
        for name in names:
            print(name)
      ]]
```
 * (This is one reason lpeg could be good to parse out commands.)
 * No more "styles" -- call them "options" instead. When a command resolves an option, it looks here, in order:
    - In the command itself, like `QQ [color=blue] :: How many ways...?`
    - A `CRTL` command \[discussed in another development note, but not yet implemented\], like `CTRL .o QQ.color=green`. This code will set the QQ.color option until overriden with another such command, or until deactivated with `CTRL .o ~QQ.color`.
    - The document's `META` settings: `OPTIONS QQ.color=gray`.
    - Globally-applied options in Latex code: `\lbtSetOption{QQ.color=navy}`.
    - Defaults set up in the command code: `o.QQ = { vspace = '6pt', color = 'blue'}`.
 * Implementation of *lbt environments* using a syntax like `+COLUMNS 2` and `-COLUMNS`. Unfortunately this clashes with `+BODY` and that can't be overlooked. An alternative might be `[+COLUMNS 2]` and `[-COLUMNS]`. Or maybe reverse it, so that lbt documents have `[@META]` and `[+BODY]` and that means we can use `+COLUMNS 2` and `-COLUMNS` as originally hoped. I think I like that idea. A lot of documents will have to be updated, but that's OK.
     - I am implementing the [@META] and [+BODY] idea now (June 2024).

### Progress towards lpeg parsing

(June 2024) It is going great. The lpeg-parsing branch is making great progress. It is working well, with just the following improvements planned:
 * Allow quoted values in dictionaries so that commas can be included if necessary.
 * Tidy up some of the code by using grammars instead of lots of local variables.

Flexible linebreaks is implemented.

lbt environments have not been implemented. Picking them up in parsing is fine, but they need to be implemented in lbt.fn.

### Progress towards opargs and kwargs

The parser picks them up, and now I need to write the code that acts on them.

**Update: completely done.** I didn't write any further notes about it here.


## Generalise COMMAND and COMMAND* (?)

It is a bit annoying (because of redunancy) to implement both TEXT and TEXT*, or PARAGRAPH and PARAGRAPH*, from scratch. Not only do they have almost identical code, but any opargs need to be repeated. Also, if the difference (as in TEXT and PARAGRAPH) is merely the presence or absence of \par, this can be coded uniformly with the new (Oct 2024) lbt.util.general_formatting_wrap(latex, o, 'nopar').

So a natural idea is that
    TEXT* blah blah blah
gets converted into
    TEXT\* .o starred :: blah blah blah
before calling the command. The handling could happen during parsing (probably not) or during Latex emission (probably). If the command ends in a star, then the opargs gets 'starred = true' set at this point. Then we can have just one TEXT, like this:

Current:

    f.TEXT = function (n, args, o)
      local paragraphs = textparagraphs(args,1)
      if o.vspace == '0pt' then
        return F([[%s \par]], paragraphs)
      else
        return F('\\vspace{%s}\n%s \\par', o.vspace, paragraphs)
      end
    end

New:

    f.TEXT = function (n, args, o)
      local result = textparagraphs(args,1)
      if o.starred then o._set_('nopar', true) end
      result = lbt.util.general_formatting_wrap(result, o, 'vspace nopar')
      return result
    end

Now, will I implement this? Not right away. I have very few starred commands at the moment, and recently started using 'nopar' (in MATH) to give the author the opportunity to suppress paragraphs.

But having this idea means I can think of other uses for starred commands in the future without worrying that it will necessarily mean annoying code redundancy.

Aside following from above:
* I should probably make 'nopar' an automatic option for every command, handled in one place. Something to think about.
* 'prespace' (for vspace inserted before) could be treated like this as well.
  - I currently have TEXT.vspace, but could change to TEXT.prespace.
  - Not vspace as this is ambiguous whether it is before or after. Maybe include postspace as well. I'm thinking of things like QQ*, which set questions side by side, and can have room for working beneath them.


## LBT Environments

I want to implement environments, like

    +COLUMNS 2 :: (pretext) \section{Heading}
    TEXT Lorem ipsum dolcetur ...
    IMAGE (filename) blah.png :: (width) 0.8
    TEXT Lorem ipsum dolcetur ...
    +INDENT (left) 3em
    TEXT Up in the air, I fly ...
    -INDENT
    TEXT Lorem ipsum dolcetur ...
    TEXT Lorem ipsum dolcetur ...
    -COLUMNS

If the contents of the environment is solely paragraphs, you can use a command instead, which closes the environment explicitly.

    COLUMNS 2 :: (pretext) \section{Heading}
    :: Lorem ipsum dolcetur ...
    :: Lorem ipsum dolcetur ...
    :: Lorem ipsum dolcetur ...
    :: Lorem ipsum dolcetur ...

There are some design notes written in Notability.

This does not replace Latex environments, of course. There is still a use case for 'BEGIN xyz' ... 'END xyz'. But common environments will likely be wrapped, meaning I can use '+COLUMNS' with keyword arguments rather than remembering the details of the Latex \begin{multicols} syntax.


## Update to QQ*

QQ* is currently a relic that does its own options parsing, like

    QQ* [ncols=3, hpack=hfill, vspace=6ex]

It is well past time to update this to

    QQ* .o ncols=3, spread=fill, workingspace=6ex

And if the 'starred' idea above takes hold, it will just be `QQ`. Working with that theory, we would have:

    QQ Show that...        (default ncols=nil)

    QQ* .o ncols=3          (default spread=columns, workingspace=0pt)
    :: $3+8$ :: $4\times7$ :: ...

    QQ* .o ncols=3, spread=fill
    :: ...

    QQ* .o ncols=3, workingspace=10ex

I like this and would like to make it happen. That 'starred' idea is looking better and better.


## General mechanism for setting Latex parameters

Say I want to set parident and topsep and ...

How do I do that in an LBT document? It would be good to have something like

    LATEX_SETTINGS .o parindent = 20pt, topsep = 2pt, ...

What is the best name?
* LATEX_SETTINGS
* VISUAL_DESIGN
* ???

I think LATEX_SETTINGS might be best.

It will take some research to determine what settings should be supported, whether they are group-local or global, that sort of thing.

It could possibly be valuable to be able to specify some settings _outside_ an LBT document and then apply them inside multiple documents. I won't rush to implement this; we'll see if the need arises.


## CTRL debug and CTRL debug-stop

I want to be able to issue a `CTRL debug-stop` command and have a lot of debugging information dumped into the PDF, then stop. This will help when something isn't quite right, or when I just want to see all available current commands, etc.


## Implementing general starred commands, and post-processing

I have written code that has condensed the implementation of TEXT(*) to the following:

    a.TEXT = '1+'
    o:append 'TEXT.starred = false'
    f.TEXT = function (n, args, o)
      local paragraphs = textparagraphs(args,1)
      if o.starred then
        o:_set_local('nopar', true)
      end
      return paragraphs
    end

No separate TEXT*. No \par at the end (this happens by default to every command; use oparg nopar to suppress). No vspace at the beginning (the oparg prespace is handled for every command automatically).

But some questions arise.
* _should_ every command automatically get a \par? It's not relevant to every command, like SECTION, for instance, or CMD, or ...
* If not, how do I limit it to relevant ones?
* Could I emphasise the positive by putting 'par = true' as the default option for relevant commands, and writing code so that specifying 'nopar' would actually set par to false?
* Can I generalise that so that any oparg noX will have the effect of setting X to false?
* And if I can, should I?

And what about prespace and postspace?
* Which commands do I want this to apply to? I think the idea was that _any_ command could have it, but in order to write 'Q .o prespace = 5ex', I need Q to support prespace. That is, I need Q to have (for instance) 'prespace = 6pt' as a default option.
* So now I'm in the same position as par/nopar. I need to look at every command and decide whether to put prespace and postspace in the default options.
* I don't want to do that.
* So the other option is to have them baked in. Every command silently supports it. Perhaps this could be implemented in _lookup. If the option is 'prespace' and we don't have a value for it, then return false.
* Although...interesting! The "So now I'm in the same position..." note above is false. I just put 'TEXT .o fobar :: Hello.' in a document and it compiled without error.
* Therefore, it _is_ possible to place 'par' or 'nopar' or 'prespace' or 'postspace' anywhere I like in the document without having to create commands with these options in mind. That's cool.

Conclusion:
* I will support prespace and postspace universally without modifying command definitions.
* I will set 'par = true' for relevant commands, and recognise 'noX' as 'X = false', either in the _setting_ of options or in the _reading_ of them. (In the latter case, calling o.par would, behind the scenes, look for par _and_ nopar.) Thus we will be able to write 'MATH .o align, nopar'.
* (Open question: should MATH* be like TEXT* and PARAGRAPH* in implying nopar? I think it should. We will dissociate * from equation numbering.)

## Generalisation of STO to allow for LBT commands

E.g.
```
    STO .o lbt :: mylist :: 10
     :: ITEMIZE .o compact
        :: Sheep
        :: Goats
        :: Cows
```

Now ◊mylist expands to `\begin{itemize} ... \end{itemize}` and it can go inside a table or colorbox or what have you.

This probably needs parser support to implement.

## READCSV and DB in lbt.Basic

I implemented `READCSV` in my HQMS project so I could read data from a TSV file and access it in template commands like HQMSITEM and BYTOPIC. This will have a wider applicability and it would be good to include it in lbt.Basic.

I also want a `DB` command so that I can have (for example) question banks. In this fantasy example, `vectors.tex` is a file containing several questions on vectors, each separated by a line that reads `% --------...` (the number of dashes is not important, but say > 8). Each item can be proceeded by a line `% key: axvg` to indicate the key for this question when it is loaded into the database.

    DB init :: vec
    DB vec :: loadfile :: sources/vectors.tex
    DB vec :: index :: 5       -- show the fifth question
    DB vec :: key :: axvg      -- show the question with that key
    DB vec :: all          -- show all in order, separated by \par
    DB .o showkey :: vec :: all
    DB .o order = random :: vec :: all
    DB vec :: keys         -- just list the keys
    DB vec :: index :: 1..3,7,9,12..20
    DB vec :: key :: axvg smtp hg85
    DB vec :: clear

Also, it will be possible to insert into the db from inside the LBT document.

    DB vec :: insert :: <
        Q Blah blah
        MC* ...
    >

Interestingly, some of the commands above demonstrate that it might be nice to allow optional arguments to appear later in the argument sequence. They are currently forced to be at the beginning.

    DB vec :: all :: .o order = random

Update 2/5/2025: DB is partially implemented. 'index' and 'key' are implemented. Not 'all'.

## Questions revamp

May 2025: I am reimplementing lbt.Questions from scratch to use tables and introduce more formatting flexibility.

## Upcoming changes to opargs

I want to shorten the names prespace and postspace to pre and post, and I want every command to be able to use them without specifying them at the command-oparg level. Implementation-wise, there will be the idea of opargs_bedrock. I can think of pre, post, center.

Speaking of opargs, it's time I implemented the validation. And for kwargs as well.

## Some ideas for refinement (9 May 2025)

* Have lbt.core.bedrock_opargs as a set containing the bedrock opargs and their default values. This serves to document their existence (sort of) and show that they are part of the core. It will also improve implementation, both looking up those arguments and checking that a command has valid opargs.
  * needspace, adjustmargins
* \lbtSettings{...} to be parsed by lbt.parser.parse_dictionary or whatever it is called. This will allow consolidation of settings and easy creation of more. For example:
    \lbtSettings{DraftMode = true, HaltOnWarning = true}
    \lbtSettings{
      CurrentContentsLevel = section,
      LogChannels = 4 emit trace,
      TemplateDirectory = PWD/templates
    }
* Have a way to expand _only_ a particular eID, like \lbtSettings{ExpandOnly = 113}
  * Blue sky thinking, but bisection debugging of an expansion would be great.
* \lbtGlobalOptions to be renamed \lbtGlobalOpargs for consistency and clarity. It is easy to confuse 'options' with 'settings'.
* Maybe \lbtCommand{...} to provide a unified interface and keep the number of \lbtX macros down.
    \lbtCommand{DefineLatexMacro}{V = lbt.Math:vector}
    \lbtCommand{PersistentCounterReset}{Hints}
* The simplemath macro (typically accessed with \sm) should use display mode \[ ... \] when the beginning and ending of the argument is space. That is, \sm{E=mc^2} is inline but \sm{ E=mc^2 } is display. (I believe Typst does this.)
  * Speaking of simplemath, I'd love to have automatic superscript, as in sm{E=mc2}. Does Typst do this? Is it a good idea?
