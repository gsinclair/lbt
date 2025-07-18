--
-- We act on the global table `lbt` and populate its subtable `lbt.test`.
--

local EQ = pl.test.asserteq
local F = string.format
local nothing = "<nil>"

----------------------------------------------------------------------

local function content_lines(text)
  return pl.List(pl.utils.split(text, "\n"))
end

-- Whip up a parsed token thing for testing
local T = function(t, n, a)
  return { token = t, nargs = n, args = pl.List(a) }
end

local sans_comments = function(L)
  return L:filter(function(x) return not x:startswith('%') end)
end
----------------------------------------------------------------------

-- For testing parsed_content_from_content_lines
local good_input_1 = content_lines([[
  !DRAFT
  [@META]
    TEMPLATE lbt.Basic
    OPTIONS  TABLE.float = true, MATH.align = true
    TRAIN    Bar :: Baz
    BUS      .d capacity=55, color=purple
  [+BODY]
    BEGIN multicols :: 2
    TEXT .o font=small :: Hello there
    END multicols
    VFILL

    ITEMIZE
      :: One
      :: Two
      :: Three
  [+EXTRA]
    TABLE .o float
      :: (caption) Phone directory
      :: (colspec) ll
      :: Name & Extension
      :: John & 429
      :: Mary & 388
    % Comment
    TEXT Hello
]])

-- For testing SOURCES
local good_input_2 = content_lines([[
  [@META]
    TEMPLATE Basic
    SOURCES  Questions, Figures, Tables
  [+BODY]
    TEXT Hello again]])

-- For testing lack of SOURCES
local good_input_3 = content_lines([[
  [@META]
    TEMPLATE Basic
  [+BODY]
    TEXT Hello again]])

-- For testing positive expansion of Basic template
local good_input_4 = content_lines([[
  [@META]
    TEMPLATE lbt.Basic
  [+BODY]
    TEXT Examples of animals:
    ITEMIZE .o topsep=0pt :: Bear :: Chameleon :: Frog
    TEXT* .o pre=30pt :: Have you seen any of these?]])

-- For testing negative expansion of Basic template
local bad_input_1 = content_lines([[
  [@META]
    TEMPLATE lbt.Basic
  [+BODY]
    TEXT
    ITEMIZE
    XYZ foo bar]])

-- For testing styles (no local override)
local good_input_5a = content_lines([[
  [@META]
    TEMPLATE TestQuestions
  [+BODY]
    TEXT Complete these questions in the space below.
    Q Evaluate:
    QQ $2+2$
    QQ $5 \times 6$
    QQ $\exp(i\pi)$
    Q Which is a factor of $x^2 + 6x + 8$?
    MC $x+1$ :: $x+2$ :: $x+3$ :: $x+4$]])

-- For testing styles (local override)
local good_input_5b = content_lines([[
  [@META]
    TEMPLATE TestQuestions
    OPTIONS  .d Q.pre = 18pt, MC.alphabet = roman
  [+BODY]
    TEXT .o pre=30pt :: Complete these questions in the space below.
    Q Evaluate:
    QQ $2+2$
    QQ $5 \times 6$
    QQ $\exp(i\pi)$
    Q Which is a factor of $x^2 + 6x + 8$?
    MC $x+1$ :: $x+2$ :: $x+3$ :: $x+4$]])

-- For testing registers
local good_input_6 = content_lines([[
  [@META]
    TEMPLATE lbt.Basic
  [+BODY]
    STO Delta :: 4 :: $b^2 - 4ac$
    STO Num   :: 4 :: $-b \pm \sqrt{◊Delta}$
    STO Den   :: 4 :: $2a$
    STO QF    :: 1000 :: $x = \frac{◊Num}{◊Den}$
    TEXT The quadratic formula is \[ ◊QF. \]
    STO fn1    :: 1 :: Hello Bolivia!
    TEXT Viewers of Roy and HG's \emph{The Dream}\footnote{◊fn1} \dots
    TEXT No longer defined: ◊fn1
    TEXT Never was defined: ◊abc
    TEXT ◊abc and $◊QF$]])

-- Content from the wild that didn't work with the lpeg parser
local good_input_7 = content_lines([[
  [@META]
    TEMPLATE   lbt.WS0
    TITLE      AMC question on divisibility
    COURSE     Archimedes Junior
    TEACHERNOTES  First used 7 March 2023. Nice work with modulo 3 arithmetic.

  [+BODY]
    TEXT Two questions from AMC Junior 2017. The first is a reasonably gentle warm-up; the second is a challenging question about divisibility and encourages us to work carefully with \emph{cases} and \emph{modular arithmetic}.
    VSPACE 1em

    Q All of the digits from 0 to 9 are used to form two five-digit numbers. What is the smallest possible difference between the two numbers?
    Q The reverse of the number 129 is 921, and these add to 1050, which is divisible by 30. How many three-digit numbers have the property that, when added to their reverse, the sum is divisible by 30?
]])

-- For testing various Basic commands
local good_input_8 = content_lines([[
  [@META]
    TEMPLATE   lbt.Basic

  [+BODY]
    TEXT Hello
    TWOPANEL Content 1 :: Content 2
    SECTION Introduction
    SECTION* Various animals
    SUBSECTION Cats
    SUBSECTION* Dogs
    SUBSUBSECTION Large
    SUBSUBSECTION* Small
    TEXT* ---------- MATH* .o align
    MATH* .o align
     :: a^2 + b^2 &= c^2
     ::         E &= mc^2
    TEXT* ---------- MATH .o align
    MATH .o align
     :: a^2 + b^2 &= c^2
     ::         E &= mc^2
    TEXT* ---------- MATH .o align, eqnum
    MATH .o align, eqnum
     :: a^2 + b^2 &= c^2
     ::         E &= mc^2
    TEXT* ---------- MATH* .o align, eqnum=1
    MATH* .o align, eqnum=1
     :: a^2 + b^2 &= c^2
     ::         E &= mc^2
    TEXT .o nopar :: Trying automatic 'noX' option resolution.
    PARAGRAPH Title 1 :: Content content.
    PARAGRAPH* Title 2 :: Content content.
    PARAGRAPH .o nopar :: Title 3 :: Content content.
    SUBPARAGRAPH (label) para-label :: Title 4 :: Content content.
]])

-- For testing QQ and MC, which have a bug (March 2025).
local good_input_9 = content_lines([[
  [@META]
    TEMPLATE   lbt.Basic

  [+BODY]
    Q What letter comes after the following?
    QQ J
    QQ X
    QQ E
]])
----------------------------------------------------------------------

local function T_DictionaryStack()
  local d = lbt.core.DictionaryStack.new()
  d:push { A = 4, B = 8, C = 9 }
  EQ(d:lookup('A'), 4)
  EQ(d:lookup('B'), 8)
  EQ(d:lookup('C'), 9)
  d:push { B = -3 }
  EQ(d:lookup('A'), 4)
  EQ(d:lookup('B'), -3)
  EQ(d:lookup('C'), 9)
  d:push { A = -1 }
  EQ(d:lookup('A'), -1)
  EQ(d:lookup('B'), -3)
  EQ(d:lookup('C'), 9)
  d:pop()
  EQ(d:lookup('A'), 4)
  EQ(d:lookup('B'), -3)
  EQ(d:lookup('C'), 9)
end

local function T_lbt_parser()
  local d = lbt.parser.parse_dictionary('city = Paris, landmark = Eiffel Tower, visited = false')
  assert(d)
  EQ(d.city, 'Paris')
  EQ(d.landmark, 'Eiffel Tower')
  EQ(d.visited, false)
end

local function T_pragmas_and_other_lines()
  lbt.api.reset_global_data()
  local input = pl.List.new{"!DRAFT", "Line 1", "!IGNORE", "Line 2", "Line 3"}
  local pragmas, lines = lbt.fn.test.pragmas_and_content(input)
  EQ(pragmas, { DRAFT = true, IGNORE = true, DEBUG = false, SKIP = false })
  EQ(lines, 'Line 1\nLine 2\nLine 3')
end

-- This uses good_input_1 to test lbt.fn.parsed_content_from_content_lines.
local function T_parsed_content_from_content_lines_1()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_1)
  EQ(pc.pragmas, { DRAFT = true, IGNORE = false, DEBUG = false, SKIP = false })
  EQ(pc.type, 'ParsedContent')
  -- check META is correct
  local m = pc:meta()
  EQ(m.TEMPLATE, 'lbt.Basic')
  EQ(m.TRAIN, 'Bar :: Baz')
  EQ(m.BUS, { capacity = 55, color = 'purple'} )
  -- check BODY is correct
  local b = pc:list_or_nil('BODY')
  assert(b)
  local b1 = { 'BEGIN', o = {}, k = {}, a = {'multicols', '2'} }
  EQ(b[1], b1)
  local b2 = { 'TEXT', o = { font = 'small' }, k = {}, a = {'Hello there'} }
  EQ(b[2], b2)
  local b3 = { 'END', o = {}, k = {}, a = {'multicols'}}
  EQ(b[3], b3)
  local b4 = { 'VFILL', o = {}, k = {}, a = {} }
  EQ(b[4], b4)
  local b5 = { 'ITEMIZE', o = {}, k = {}, a = {'One', 'Two', 'Three'} }
  EQ(b[5], b5)
  -- check EXTRA is correct
  local e = pc:list_or_nil('EXTRA')
  assert(e)
  local e1 = { 'TABLE', o = { float = true },
    k = { caption = 'Phone directory', colspec = 'll' },
    a = {'Name & Extension', 'John & 429', 'Mary & 388'} }
  EQ(e[1], e1)
  local e2 = { 'TEXT', o = {}, k = {}, a = {'Hello'} }
  EQ(e[2], e2)
end

local function T_extra_sources()
  lbt.api.reset_global_data()
  -- We assume parsed_content_from_content_lines works for these inputs.
  local pc2 = lbt.fn.parsed_content_from_content_lines(good_input_2)
  local pc3 = lbt.fn.parsed_content_from_content_lines(good_input_3)
  local s2  = pc2:extra_sources()
  local s3  = pc3:extra_sources()
  EQ(s2, {"Questions", "Figures", "Tables"})
  EQ(s3, {})
end

local function T_resolve_oparg()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_1)
  local t  = pc:template_object_or_error()
  local ctx = lbt.fn.ExpansionContext.new {
    pc = pc,
    template = t,
    sources = lbt.fn.test.consolidated_sources(pc, t)
  }
  local f = function(qkey)
    local t = table.pack(ctx:resolve_oparg(qkey))
    t.n = nil
    return t
  end
  -- default opargs
  EQ(f('TEXT.starred'), { true, false })
  EQ(f('TEXT.par'), { true, true })
  EQ(f('VSPACE.starred'), { true, false })
  EQ(f('ITEMIZE.sep'), { true, 1 })
  EQ(f('MATH.env'), { true, nil })
  EQ(f('MATH.gathered'), { true, false })
  EQ(f('TABLE.position'), { true, 'htbp' })
  -- nonexistent opargs
  EQ(f('TABLE.xyz'), { false, nil })
  EQ(f('FOOBAR.xyz'), { false, nil })
  -- overridden opargs
  EQ(f('TABLE.float'), { true, true })
  EQ(f('MATH.align'), { true, true })
end

local function T_command_spec()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_1)
  local t  = pc:template_object_or_error()
  local ctx = lbt.fn.ExpansionContext.new {
    pc = pc,
    template = t,
    sources = lbt.fn.test.consolidated_sources(pc, t)
  }
  local cspec
  cspec = ctx:command_spec('VSPACE')
  assert(cspec ~= nil)
  EQ(cspec.opcode, 'VSPACE')
  EQ(cspec.source, 'lbt.Basic')
  EQ(cspec.starred, false)
  cspec = ctx:command_spec('VSPACE*')
  assert(cspec ~= nil)
  EQ(cspec.opcode, 'VSPACE*')
  EQ(cspec.refer, 'VSPACE')
  EQ(cspec.source, 'lbt.Basic')
  EQ(cspec.starred, true)
  cspec = ctx:command_spec('SUBPARAGRAPH')
  assert(cspec ~= nil)
  EQ(cspec.opcode, 'SUBPARAGRAPH')
  EQ(cspec.source, 'lbt.Basic')
  EQ(cspec.starred, false)
  EQ(cspec.posargs, {2,9999})
  EQ(cspec.opargs, { starred = false, par = true })
  EQ(cspec.kwargs, nil)
end

local function T_load_templates_from_directory()
  lbt.api.reset_global_data()
  local t1 = lbt.fn.Template.object_by_name_or_nil("HSCLectures")
  assert(t1 == nil)
  lbt.api.load_templates_from_directory("PWD/test/TEST-templates")
  -- Note: the TEST-templates directory has a file HSCLectures.lua in it.
  local t2 = lbt.fn.Template.object_by_name("HSCLectures")
  local p2 = lbt.fn.Template.path_by_name("HSCLectures")
  assert(t2.name == "HSCLectures")
  assert(t2.desc == "A test template for the lbt project")
  assert(t2.sources[1] == "lbt.Questions")
  assert(p2:endswith("test/TEST-templates/HSCLectures.lua"))
end

local function T_expand_Basic_template_1()
  lbt.api.reset_global_data()
  lbt.fn.Template.register_to_logfile()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_4)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  EQ(l[2], [[Examples of animals:]])
  EQ(l[3], [[\par]])
  assert(l[5]:lfind("\\item Bear"))
  assert(l[5]:lfind("\\item Chameleon"))
  assert(l[5]:lfind("\\item Frog"))
  EQ(l[7], [[\vspace{30pt}]])
  EQ(l[8], [[Have you seen any of these?]])
  EQ(l[9], nil)
end

local function T_expand_Basic_template_2()
  lbt.api.reset_global_data()
  lbt.fn.Template.register_to_logfile()
  local pc = lbt.fn.parsed_content_from_content_lines(bad_input_1)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  assert(l[1]:lfind([[Opcode \Verb|TEXT| raised error]]))
  assert(l[1]:lfind([[0 args given but 1+ expected]]))
  assert(l[2]:lfind([[Opcode \Verb|ITEMIZE| raised error]]))
  assert(l[2]:lfind([[0 args given but 1+ expected]]))
  assert(l[3]:lfind([[Opcode \Verb|XYZ| not resolved]]))
end

local function T_util()
  lbt.api.reset_global_data()
  -- Splitting text
  EQ(lbt.util.double_colon_split('a :: b :: c'), {'a', 'b', 'c'})
  EQ(lbt.util.space_split('a b c'),    {'a', 'b', 'c'})
  EQ(lbt.util.space_split('a b c', 2), {'a', 'b c'})
  EQ(lbt.util.comma_split('one,two   ,     three'), {'one','two','three'})
  local t = 'My name is !NAME!, age !AGE!, and I am !ADJ! to see you'
  local v = { NAME = 'Jon', AGE = 37, ADJ = 'pleased', JOB = 'Technician' }
  EQ(lbt.util.string_template_expand1(t, v), 'My name is Jon, age 37, and I am pleased to see you')
  local t = {
    'The rain in !COUNTRY!',
    { 'this should not be included', include = false },
    { 'falls mainly on the', include = true },
    '!OBJECT!, so I am told.',
    values = { COUNTRY = 'Spain', OBJECT = 'plain' }
  }
  EQ(lbt.util.string_template_expand(t), 'The rain in Spain\nfalls mainly on the\nplain, so I am told.')
  local a, b = lbt.util.parse_range('4..17')
  EQ(a, 4); EQ(b, 17)
  a, b = lbt.util.parse_range('6')
  EQ(a, 6); EQ(b, 6)
  local d = lbt.util.parse_date('2023-07-22')
  EQ(d:year(), 2023); EQ(d:month(), 7); EQ(d:day(), 22)
  EQ(d:hour(), 12); EQ(d:min(), 0); EQ(d:sec(), 0)
  -- Analyse list items for their different levels
  local args = pl.List{'Cats', '* Black', '* White', 'Dogs', '* Large', '* * Labrador', '* * Bloodhound', '* Small', '* * Toy poodle',}
  local expected1 = {{0, 'Cats'}, {1, 'Black'}, {1, 'White'}, {0, 'Dogs'}, {1, 'Large'}, {2, 'Labrador'}, {2, 'Bloodhound'}, {1, 'Small'}, {2, 'Toy poodle'}}
  local expected2 = {{0, {'Cats'}}, {1, {'Black', 'White'}}, {0, {'Dogs'}}, {1, {'Large'}}, {2, {'Labrador', 'Bloodhound'}}, {1, {'Small'}}, {2, {'Toy poodle'}}}
  local out1 = lbt.util.analyse_indented_items(args)
  local out2 = lbt.util.analyse_indented_items(args, 'grouped')
  EQ(out1, expected1)
  EQ(out2, expected2)
end



local function T_number_in_alphabet()
  lbt.api.reset_global_data()
  local f = lbt.util.number_in_alphabet
  EQ(f(15, 'latin'), 'o')
  EQ(f(15, 'Latin'), 'O')
  EQ(f(15, 'roman'), 'xv')
  EQ(f(15, 'Roman'), 'XV')
end

local function T_styles_in_test_question_template_5a()
  lbt.api.reset_global_data()
  lbt.api.load_templates_from_directory("PWD/test/TEST-templates")
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_5a)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  l = sans_comments(l)
  EQ(l[1], [[Complete these questions in the space below.]])
  EQ(l[2], [[\par]])
  EQ(l[3], [[\vspace{12pt}]])
  EQ(l[4], [[\bsferies\color{blue}Question~1}\enspace Evaluate:]])
  EQ(l[5], [[(a)~$2+2$]])
  EQ(l[6], [[(b)~$5 \times 6$]])
  EQ(l[7], [[(c)~$\exp(i\pi)$]])
  EQ(l[8], [[\vspace{12pt}]])
  EQ(l[9], [[\bsferies\color{blue}Question~2}\enspace Which is a factor of $x^2 + 6x + 8$?]])
  EQ(l[10], [[(MC A) \quad $x+1$\\]])
  EQ(l[11], [[(MC B) \quad $x+2$\\]])
  EQ(l[12], [[(MC C) \quad $x+3$\\]])
  EQ(l[13], [[(MC D) \quad $x+4$\\]])
  EQ(l[14], nil)
end

local function T_styles_in_test_question_template_5b()
  lbt.api.reset_global_data()
  lbt.api.load_templates_from_directory("PWD/test/TEST-templates")
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_5b)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  l = sans_comments(l)
  EQ(l[1], [[\vspace{30pt}]])
  EQ(l[2], [[Complete these questions in the space below.]])
  EQ(l[3], [[\par]])
  EQ(l[4], [[\vspace{18pt}]])
  EQ(l[5], [[\bsferies\color{blue}Question~1}\enspace Evaluate:]])
  EQ(l[6], [[(a)~$2+2$]])
  EQ(l[7], [[(b)~$5 \times 6$]])
  EQ(l[8], [[(c)~$\exp(i\pi)$]])
  EQ(l[9], [[\vspace{18pt}]])
  EQ(l[10], [[\bsferies\color{blue}Question~2}\enspace Which is a factor of $x^2 + 6x + 8$?]])
  EQ(l[11], [[(MC i) \quad $x+1$\\]])
  EQ(l[12], [[(MC ii) \quad $x+2$\\]])
  EQ(l[13], [[(MC iii) \quad $x+3$\\]])
  EQ(l[14], [[(MC iv) \quad $x+4$\\]])
end

local function T_register_expansion()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_6)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  EQ(l[2], [=[The quadratic formula is \[ \ensuremath{x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}}. \]]=])
  EQ(l[3], [[\par]])
  EQ(l[5], [[Viewers of Roy and HG's \emph{The Dream}\footnote{Hello Bolivia!} \dots]])
  EQ(l[6], [[\par]])
  EQ(l[8], [[No longer defined: ◊fn1]])
  EQ(l[9], [[\par]])
  EQ(l[11], [[Never was defined: ◊abc]])
  EQ(l[12], [[\par]])
  EQ(l[14], [[◊abc and $\ensuremath{x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}}$]])
  EQ(l[15], [[\par]])
  EQ(l[16], nil)
end

local function T_simplemath()
  -- We need an ExpansionContext to run the simplemath macro
  local ctx = lbt.fn.ExpansionContext.test_ctx { 'lbt.Math', 'lbt.Basic' }
  lbt.core.set_log_channels('allbuttrace', 'space')
  -- Gain backdoor access to the simplemath macro
  local t = lbt.fn.Template.object_by_name('lbt.Math')
  local m = t.macros.simplemath
  local assert_math = function(input, expected)
    local actual = m(input, ctx)
    EQ(actual, F([[\ensuremath{%s}]], expected), nil, 1)
  end
  local assert_math_parses = function(input)
    local tokens = t.macros.simplemathtokens(input)
    assert(tokens)
  end
  assert_math([[\alpha]], [[\alpha]])
  assert_math([[\text]], [[\text]])
  assert_math([[n \text]], [[n \text]])
  assert_math([[n \text{ is odd} implies n^2 \text{ is odd}]], [[n \text{ is odd} \implies n^2 \text{ is odd}]])
  assert_math([[\br{ sqrt n }^n le n! le \br{ frac {n+1} 2 }^n\,.]],
              [[\br{ \sqrt n }^n \le n! \le \br{ \frac {n+1} 2 }^n\,.]])
  assert_math([[sin2 th = 0.32]], [[\sin^{2} \theta = 0.32]])
  assert_math([[cot32 b]], [[\cot^{32} b]])
  assert_math([[cot32 B]], [[\cot^{32} B]])
  assert_math([[a^2 + b^2 = c^2]], [[a^2 + b^2 = c^2]])
  assert_math([[forall n in \nat, n+1 > n]], [[\forall n \in \nat, n+1 > n]])
  assert_math([[lim_{n to infty} 1/n = 0]], [[\lim_{n \to \infty} 1/n = 0]])
  assert_math([[x ge alpha]], [[x \ge \alpha]])
  assert_math([[alpha beta gamma]], [[\alpha \beta \gamma]])
  assert_math([[OABC PQR XY]], [[\mathit{OABC} \mathit{PQR} \mathit{XY}]])
  assert_math([[D = \set {w in \bbC mid \abs {w} le 1}]],
    [[D = \set {w \in \bbC \mid \abs {w} \le 1}]])
  assert_math([[exists n in \bbN: n text{ is prime }]], [[\exists n \in \bbN: n \text{ is prime }]])
  assert_math([[exists n in \bbN: n \text{ is prime }]], [[\exists n \in \bbN: n \text{ is prime }]])
  -- Test that \text{...} is picked up and passed through.
  assert_math([[abc \text{reader to confirm} def]], [[abc \text{reader to confirm} def]])
  -- Test automatic \left and \right
  assert_math([[(a + (b+c)^2)^2]], [[\left(a + \left(b+c\right)^2\right)^2]])
  assert_math([[y = [frac x 7] \text{(where $[a]$ is the rounding function)}]],
              [[y = \left[\frac x 7\right] \text{(where $[a]$ is the rounding function)}]])
  assert_math([[f(x) &= x^3 - 7x^2 + 4x + 1]], [[f\left(x\right) &= x^3 - 7x^2 + 4x + 1]])
  assert_math([[h'(x) &= 3^x\:ln 3]], [[h'\left(x\right) &= 3^x\:\ln 3]])
  assert_math([[xxx]], [[xxx]])
  assert_math_parses([[\intertext{Divide both sides by $r$}]])
end

local function T_Basic_various()
  lbt.api.reset_global_data()
  lbt.fn.Template.register_to_logfile()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_8)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  l = sans_comments(l)
  assert(l[1]:lfind('Hello'))
  assert(l[2]:lfind('\\par'))
  assert(l[3]:lfind('minipage'))
  assert(l[3]:lfind('Content 1'))
  assert(l[3]:lfind('Content 2'))
  EQ(l[4], [[\section{Introduction} ]])
  EQ(l[5], [[\section*{Various animals} ]])
  EQ(l[6], [[\subsection{Cats} ]])
  EQ(l[7], [[\subsection*{Dogs} ]])
  EQ(l[8], [[\subsubsection{Large} ]])
  EQ(l[9], [[\subsubsection*{Small} ]])
  EQ(l[10], [[---------- MATH* .o align]])
  assert(l[11]:lfind([[\begin{align*}]]))
  assert(l[11]:lfind([[\end{align*}]]))
  assert(not l[11]:lfind([[\par]]))
  EQ(l[12], [[---------- MATH .o align]])
  assert(l[13]:lfind([[\begin{align*}]]))
  assert(l[13]:lfind([[\end{align*}]]))
  assert(not l[13]:lfind([[\par]]))
  EQ(l[14], [[\par]])
  EQ(l[15], [[---------- MATH .o align, eqnum]])
  assert(l[16]:lfind([[\begin{align}]]))
  assert(l[16]:lfind([[\end{align}]]))
  assert(not l[16]:lfind([[\par]]))
  EQ(l[17], [[\par]])
  EQ(l[18], [[---------- MATH* .o align, eqnum=1]])
  assert(l[19]:lfind([[\begin{align}]]))
  assert(l[19]:lfind([[a^2 + b^2 &= c^2 \\]]))
  assert(l[19]:lfind([[E &= mc^2 \notag]]))
  assert(l[19]:lfind([[\end{align}]]))
  assert(not l[19]:lfind([[\par]]))
  EQ(l[20], [[Trying automatic 'noX' option resolution.]])
  --
  -- The block below is commented out becaues I do not currently have noX oparg parsing
  -- implemented. Was it implemented before and lost in the great refactor? Who knows.
  --
  -- EQ(l[21], '\\paragraph{Title 1} \nContent content.')
  -- EQ(l[22], '\\par')
  -- EQ(l[23], '\\paragraph{Title 2} \nContent content.')
  -- EQ(l[24], '\\paragraph{Title 3} \nContent content.')
  -- EQ(l[25], '\\subparagraph{Title 4} \\label{para-label}\nContent content.')
  -- EQ(l[26], '\\par')
  -- EQ(l[27], nil)
  --
  -- assert(l[10]:lfind([[xxx]]))
  -- assert(l[10]:lfind([[xxx]]))
  -- assert(l[10]:lfind([[xxx]]))
  -- assert(l[10]:lfind([[xxx]]))
end

local function T_QQ_MC()
  lbt.api.reset_global_data()
  lbt.fn.Template.register_to_logfile()
  local pc = lbt.fn.parsed_content_from_content_lines(good_input_9)
  lbt.fn.ParsedContent.validate(pc)
  local l  = lbt.fn.latex_expansion_of_parsed_content(pc)
  -- assert(l[1]:lfind('Hello'))
end

function T_lbt_commands_text_into_latex()
  local input, output
  input = 'CMD bigskip'
  output = lbt.util.lbt_commands_text_into_latex(input)
  EQ(output, [[\bigskip]])
end
----------------------------------------------------------------------

local function RUN_TESTS()
  print("\n\n======================= <TESTS>")
  lbt.fn.lbt_test_mode(true)

  T_lbt_parser()
  T_pragmas_and_other_lines()
  T_DictionaryStack()
  T_parsed_content_from_content_lines_1()
  T_extra_sources()
  T_resolve_oparg()
  T_command_spec()
  T_load_templates_from_directory()
  -- T_expand_Basic_template_1()
  -- T_expand_Basic_template_2()
  T_util()
  T_number_in_alphabet()
  -- T_styles_in_test_question_template_5a()
  -- T_styles_in_test_question_template_5b()
  -- T_register_expansion()
  T_simplemath()
  -- T_Basic_various()
  -- T_QQ_MC()
  -- T_lbt_commands_text_into_latex()

  lbt.fn.lbt_test_mode(false)
  print("======================= </TESTS> (exiting)")
  os.exit(0)
end

function lbt.test.run_tests()
  RUN_TESTS()
end
