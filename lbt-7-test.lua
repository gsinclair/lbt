--
-- We act on the global table `lbt` and populate its subtable `lbt.test`.
--

local pp = pl.pretty.write
local EQ = pl.test.asserteq

--------------------------------------------------------------------------------

local function content_lines(text)
  return pl.List(pl.utils.split(text, "\n")):map(string.strip)
end

-- Whip up a parsed token thing for testing
local T = function(t, n, a, r)
  return { token = t, nargs = n, args = pl.List(a), raw = r }
end

--------------------------------------------------------------------------------

local good_input = content_lines([[
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
  local pc = lbt.fn.parsed_content(good_input)
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

--------------------------------------------------------------------------------

local function RUN_TESTS()
  lbt.api.set_debug_mode(true)
  T_pragrams_and_other_lines()
  T_parsed_content_1()
end

RUN_TESTS()


