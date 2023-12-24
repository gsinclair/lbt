--
-- We act on the global table `lbt` and populate its subtable `lbt.test`.
--

local pp = pl.pretty.write
local EQ = pl.test.asserteq
local nothing = "<nil>"

--------------------------------------------------------------------------------

local function content_lines(text)
  return pl.List(pl.utils.split(text, "\n")):map(string.strip)
end

-- Whip up a parsed token thing for testing
local T = function(t, n, a, r)
  return { token = t, nargs = n, args = pl.List(a), raw = r }
end

--------------------------------------------------------------------------------

-- For testing parsed_content
local good_input_1 = content_lines([[
  !DRAFT
  @META
    TEMPLATE Basic
    FOO      Bar
  +BODY
    BEGIN multicols :: 2
    TEXT Hello there
    END multicols
    VSPACE 30pt
    VFILL
    TEXT Hello again]])

-- For testing SOURCES
local good_input_2 = content_lines([[
  @META
    TEMPLATE Basic
    SOURCES  Questions, Figures, Tables
  +BODY
    TEXT Hello again]])

-- For testing lack of SOURCES
local good_input_3 = content_lines([[
  @META
    TEMPLATE Basic
  +BODY
    TEXT Hello again]])

-- For testing positive expansion of Basic template
local good_input_4 = content_lines([[
  @META
    TEMPLATE lbt.Basic
  +BODY
    TEXT Examples of animals:
    ITEMIZE  [topsep=0pt] :: Bear :: Chameleon :: Frog
    TEXT 30pt :: Have you seen any of these?]])

-- For testing negative expansion of Basic template
local bad_input_1 = content_lines([[
  @META
    TEMPLATE lbt.Basic
  +BODY
    TEXT
    TEXT a :: b :: c
    ITEMIZE
    XYZ foo bar]])

--------------------------------------------------------------------------------

local function T_pragrams_and_other_lines()
  local input = pl.List.new{"!DRAFT", "Line 1", "!IGNORE", "Line 2", "Line 3"}
  local pragmas, lines = lbt.fn.impl.pragmas_and_other_lines(input)
  lbt.dbg(pp(pragmas))
  lbt.dbg(pp(lines))
  EQ(pragmas, { draft = true, ignore = true, debug = false })
  EQ(lines, pl.List.new({"Line 1", "Line 2", "Line 3"}))
end

local function T_parsed_content_1()
  -- DEBUG(pp(input))
  local pc = lbt.fn.parsed_content(good_input_1)
  lbt.dbg(pc)
  local exp_pragmas = { draft = true, debug = false, ignore = false }
  EQ(pc.pragmas, exp_pragmas)
  local exp_meta = {
    TEMPLATE = "Basic",
    FOO      = "Bar"
  }
  EQ(pc.META, exp_meta)
  local exp_body = {
    T("BEGIN", 2, {"multicols","2"}, "multicols :: 2"),
    T("TEXT", 1, {"Hello there"}, "Hello there"),
    T("END", 1, {"multicols"}, "multicols"),
    T("VSPACE", 1, {"30pt"}, "30pt"),
    T("VFILL", 0, {}, ""),
    T("TEXT", 1, {"Hello again"}, "Hello again"),
  }
  EQ(pc.BODY[1], exp_body[1])
  EQ(pc.BODY[2], exp_body[2])
  EQ(pc.BODY[3], exp_body[3])
  EQ(pc.BODY[4], exp_body[4])
  EQ(pc.BODY[5], exp_body[5])
  EQ(pc.BODY[6], exp_body[6])
  EQ(pc.BODY, exp_body)
end

local function T_extra_sources()
  -- We assume parsed_content works for these inputs.
  local pc2 = lbt.fn.parsed_content(good_input_2)
  local pc3 = lbt.fn.parsed_content(good_input_3)
  local s2  = lbt.fn.pc.extra_sources(pc2)
  local s3  = lbt.fn.pc.extra_sources(pc3)
  assert(s2 == pl.List{"Questions", "Figures", "Tables"})
  assert(s3 == pl.List{})
end

local function T_add_template_directory()
  local t1 = lbt.fn.template_object_or_nil("HSCLectures")
  local p1 = lbt.fn.template_path_or_nil("HSCLectures")
  assert(t1 == nil and p1 == nil)
  lbt.api.add_template_directory("PWD/templates")
  -- Note: the templates directory has a file HSCLectures.lua in it.
  local t2 = lbt.fn.template_object_or_nil("HSCLectures")
  local p2 = lbt.fn.template_path_or_nil("HSCLectures")
  assert(t2 ~= nil and p2 ~= nil)
  assert(t2.name == "HSCLectures")
  assert(t2.desc == "A test template for the lbt project")
  assert(t2.sources[1] == "lbt.Questions")
  assert(p2:endswith("test/templates/HSCLectures.lua"))
end

local function T_expand_Basic_template_1()
  lbt.fn.template_register_to_logfile()
  local pc = lbt.fn.parsed_content(good_input_4)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  EQ(l[1], [[Examples of animals: \par]])
  assert(l[2]:lfind("\\item Bear"))
  assert(l[2]:lfind("\\item Chameleon"))
  assert(l[2]:lfind("\\item Frog"))
  EQ(l[3], [[\vspace{30pt} Have you seen any of these? \par]])
end

local function T_expand_Basic_template_2()
  lbt.fn.template_register_to_logfile()
  local pc = lbt.fn.parsed_content(bad_input_1)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  assert(l[1]:lfind("Token TEXT raised error"))
  assert(l[1]:lfind("0 args given but 1-2 expected"))
  assert(l[2]:lfind("Token TEXT raised error"))
  assert(l[2]:lfind("3 args given but 1-2 expected"))
  assert(l[3]:lfind("Token ITEMIZE raised error"))
  assert(l[3]:lfind("0 args given but 1+ expected"))
  assert(l[4]:lfind("Token XYZ not resolved"))
end


--------------------------------------------------------------------------------

local function RUN_TESTS(exit_on_completion)
  print("\n\n======================= <TESTS>")
  lbt.api.set_debug_mode(true)

  -- T_pragrams_and_other_lines()
  -- T_parsed_content_1()
  -- T_extra_sources()
  -- T_add_template_directory()
  T_expand_Basic_template_2()

  if exit_on_completion then
    print("======================= </TESTS> (exiting)")
    os.exit()
  else
    print("======================= </TESTS>")
  end
end

RUN_TESTS(1)
