--
-- We act on the global table `lbt` and populate its subtable `lbt.test`.
--

lbt.api.set_debug_mode(true)

local pp = pl.pretty.write
local EQ = pl.test.asserteq

local function T_pragrams_and_other_lines()
  local input = pl.List.new{"!DRAFT", "Line 1", "!IGNORE", "Line 2", "Line 3"}
  pragmas, lines = lbt.fn.impl.pragmas_and_other_lines(input)
  lbt.dbg(pp(pragmas))
  lbt.dbg(pp(lines))
  EQ(pragmas, { draft = true, ignore = true, debug = false })
  EQ(lines, pl.List.new({"Line 1", "Line 2", "Line 3"}))
end

-- T_pragrams_and_other_lines()
