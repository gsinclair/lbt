# Scratch file for documentation

## Wouldn't it be great if...

To understand what `lbt` has to offer, it is probably best to understand its motivations. That way, a potential author can see if the motivations make sense to them. That informs the way the following paragraphs are written.

**Wouldn't it be great if the "commands" that make up the structure of the document were clear?** It is nice to write questions and subquestions and multiple-choice options using `Q` and `QQ` and `MC` without a lot of `begin` and `end`. The design of `lbt` emphasises *commands* so that it is always clear what we are doing with the text, even if it is just `TEXT Lorem ipsum...`. An excerpt from a worksheet source code is shown below.

    TEXT Complete the questions on this page in \textbf{under ten minutes}.
    Q Solve the following equations:
    COLUMNS 2
    QQ $x + 7 = 3$
    QQ $2x + 12 = 28$
    ...
    QQ $\half x - 10 = 5$
    ENDCOLUMNS
    VSPACE 30pt
    Q Evaluate the following expressions when $x=9$.
    COLUMNS 2
    QQ $4x-1$
    QQ $4x-1$
    QQ $4x-1$
    QQ $4x-1$
    ENDCOLUMNS
    TEXT From this exercise I hope you have improved your:
    ITEMIZE speed :: awareness :: accuracy.
    CLEARPAGE

**Wouldn't it be great if we could write Latex commands to simplify our document without a lot of backslashes and braces?** For a research article or book that is mostly text (and equations, say), the Latex syntax is not too bad: most of the source code is actual text, and the Latex commands to handle figures etc. are pulling their weight. But if you write heavily structured content (an exam, or a CV, or a theatrical play) then you end up with a lot more commands and environments. They are doing a great job, but they are verbose and obscure the content.

LBT code, on the other hand, avoids backslashes and braces almost entirely. Commands are upper-case words at the beginning of the line. Arguments are separated by ` :: `, which is easy to type, and the resulting source code is spread out and easier to read.

Items in a list are simply arguments to `ITEMIZE`, which is far less verbose than `\begin{itemize} \item ... \item ... \item ... \end{itemize}`.

**Wouldn't it be great if we could write Latex commands to simplify our document using a programming language that makes conditionals and looping easy?** This opens many doors to simplification, like handling a variable number of arguments gracefully.

**Wouldn't it be great if we could write commands without checking whether they clash with built-in commands and without trampling the global namespace?** When you define `Q` to mean "question", it takes effect only in an `lbt` environment, and only if the relevant template is selected. It does not interfere with any Latex command.

**Wouldn't it be great if we could write collections of commands in Lua and reuse them between documents without much hassle?** Your template commands live in a Lua file. You put that in whatever directory you like (suggestion: `$HOME/lbt-templates` or similar). You tell `lbt` where to look with `\lbtTemplateDiretory`, and now everything you have written is available. If you collaborate with someone else and they put their templates somewhere else, you will have to work out the logistics, but this is a small price to pay for the convenience.

**Wouldn't it be great if we could define local variables to help us build up complicated reusable content?** LBT has the concept of a register. You `STO`re a value in a named register and recall the value later, in your content. Each register has a *time-to-live*, so you effectively have a local variable and everything is neat and tidy. This mechanism is separate from Latex commands. Registers are math-aware, meaning their evaluation will include `\ensuremath{...}` if necessary, and only as much as necessary.

A good simple example, demonstrated fully elsewhere, is the quadratic formula. While it is not too complicated to typeset inline, it might be nice to put in a register called `QF` and use it throughout the document, if it is going to be rendered more than once.

    STO $num :: 1 :: $-b \pm \sqrt{b^2 - 4ac}$
    STO $den :: 1 :: 2a
    STO $QF  :: 999 :: $x = \frac{◊num}{◊den}

    TEXT Given a quadratic equation $ax^2 + bx + c = 0, we can always find
     » the two (real or complex, unique or otherwise) solutions with \[ ◊QF. \]

The `num` and `den` registers expire almost immediately, but `QF` lives a long time because we want to be able to use it.

**Wouldn't it be great if we could write commands with several arguments without surrounding {each}{argument}{in}{braces}?** As the `STO` command above exemplifies, arguments are separated by `::`. This is uniform for all commands. When you write the code for a command, the argument-separation has already occurred. And in fact, you can specify in advance how many commands (a range) are allowed, and `lbt` will raise an error if this is not met. For example, `TEXT` takes one or two commands (the first being an optional vspace before the paragraph), and the code could hardly be simpler:

    a.TEXT = '1-2'
    c.TEXT = function (n, args)
        if n == 1 then
            return args[1] .. [[ \par]]
        elseif n == 2 then
            return string.format([[\vspace{%s} \par %s \par]], args[1], args[2])
        end
    end

Notice that the function returns a string of Latex code, which the core of LBT emits into the Latex stream during compilation.

**Wouldn't it be great if we could write Latex macros in Lua that help express the content but don't (necessarily) pollute the global namespace?** LBT has the concept of "macros" (exactly like Latex macros). You write them in Lua as part of a template. If you wish to use them, you call `lbtDefineLatexMacro{...}` to make it available globally, or you call `MACROS ...` in a template expansion to make it available locally. A nice example is `\Integral{0,\infty,e{x^2},dx}` that uses a comma-separated list of arguments to typeset a definite or indefinite integal. Because of Lua the implementation is feasible, and because of LBT the logistics are simple.

**Wouldn't it be great if we could apply styles at different levels: document-wide, template-local?** As a simple example, a "question" in `lbt.Questions` appears in long-form ("Question 7") and in blue. If you want it to be medium form or short form ("Q7" or "7"), or if you want to change the colour, both of these can happen. The template code specifies the default styles like so:

    a.Q = 1
    s.Q = { vspace = '6pt', color = 'blue', format = 'long' }
    c.Q = function (n, args, sr)
        local vsp, col, form = sr('Q.vspace Q.color Q.format')
        ... code ...
    end

So the defaults are in place. If you want to change them document-wide, do

    \lbtStyles{Q.vspace 30pt :: Q.color PeachPuff}

If you want to change it for just one template expansion:

    @META
        TEMPLATE   Exam
        STYLES     Q.vspace 12pt :: Q.format short
    +BODY
        ...

If you want to change the way questions are rendered more significantly, write your own template that includes a `Q` command, and *include* it in your document. It will take precedence over the existing definition.

    (MyQuestions.lua)
    ...
    c.Q = function(n, args, sr)
        ...
    end

    (Document.tex)
    \begin{lbt}
        @META
            TEMPLATE  Exam
            INCLUDE   MyQuestions
        ...
    \end{lbt}

**Wouldn't it be great if we could achieve what we want *within* Latex, instead of working in Markdown (say) and *compiling* to Latex?** Many people find success writing documents in Markdown or something else, then using `pandoc` or some other workflow to generate PDF via Latex. There are no doubt ways of styling and customising the result, and hopefully there are ways to add your own structural features (questions, actor lines, etc.) to the document.

The LBT alternative is that your document *is* in Latex, and you have all the upsides of that, but you enhance the writing process by expressing your structured content in LBT and having that compiled into the document from the inside rather than from the outside. This gives you much more flexibility.
