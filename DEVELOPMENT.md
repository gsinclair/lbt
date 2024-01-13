# LBT development notes

This is not an appending journal. It is a live document with a place to design and/or document features. Ultimately the information either withers or ends up in proper documentation.


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
        @META
            TEMPLATE   lbt.WS0
            SOURCES    Math
            MACROS     defint,indefint,myvec
        +BODY
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
      @META
        TEMPLATE lbt.Basic
        SOURCES  Poetry
      +BODY
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
    --     @META
    --       TEMPLATE    Exam
    --       STYLE       Q.vspace 30pt :: Q.color gray :: MC.alphabet roman
    --     +BODY
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
