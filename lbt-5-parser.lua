--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

local lpeg = require 'lpeg'

-- When parsing, we track the furthest that the parser gets, to help
-- us find invalid text when the parser fails.
local MaxPosition = -1

-- {{{ Preamble: local conveniences
local F = string.format
local D = pl.pretty.dump

local P = lpeg.P   -- pattern   P'hello'
local S = lpeg.S   -- set       S'aeiou'            /[aeiou]/
local R = lpeg.R   -- range     R('af','AF','09')   /[a-fA-F0-9]/
-- P(3) matches 3 characters unconditionally
-- P(3) * 'hi' matches 3 characters followed by 'hi'
local loc = lpeg.locale()
local Alpha = loc.alpha
local Upper = loc.upper
local Digit = loc.digit
local KeywordChar = loc.alpha + '_'
local Alnum = loc.alpha + loc.digit
-- loc.space^0 * loc.alpha^1      /\s*\w+/
-- P'-'^-1 * R'0-9'^3             /-?\d{3,}/
-- (P'ab' + 'a') * 'c'            /(ab|a)c/
local C = lpeg.C   -- simple capture
-- loc.space^0 * C(loc.alpha^1)   /\s*(\w+)/     capture word
-- C(C(2) * 1 * C(2)) match "hello"  --> hello  he  lo
local Cp = lpeg.Cp -- position capture
-- sp = loc.space^0
-- word = loc.alpha^1
-- (sp * Cp() * word)^0   match  "one three two"  --> 1  5  11"
local Ct = lpeg.Ct -- table capture
local Cs = lpeg.Cs -- string capture [read more about this]
local Cc = lpeg.Cs -- constant capture [read more about this]
local V = lpeg.V

-- }}}

-- {{{ Fundamental parsing units, like space, position, tag function, integer
local tag = function(type)
  return function(x)
    return { type = type, value = x }
  end
end
local Pos = P(
  function (_, i)
    MaxPosition = math.max(MaxPosition, i)
    return true
  end
)
-- nl = newline
-- hsp = optional horizontal space; hspace = mandatory horizontal space
-- sp = optional space (incl newline); space = mandatory space (incl newline)
local nl = P'\n'
local hsp = (S' \t')^0
local hspace = (S' \t')^1
local sp = (S' \t\n')^0
local space = (S' \t\n')^1
local RestOfLine = (P(1) - nl)^1
local Symbol = S'_.*'
-- identifier can be like foo or foo_bar or foo.bar or TEXT*.vsp
local identifier = Alpha * (Alpha + Digit + Symbol)^1
local integer = (P('-')^-1 * R'19' * (R'09')^0) / tonumber
local integer_only = integer * -1
local dquote = P('"')
-- }}}

-- {{{ Key-value list (used in optargs and in META values like OPTIONS etc.)
local process_kvlist = function(data)
  local result = {}
  for _, x in ipairs(data) do
    local k = x.value[1]
    local v = x.value[2]
    result[k] = (v == nil and true) or v
    -- TODO: consider collecting solo keys (those with no values) in a list
  end
  return result
end
local parsed_value = P{'value',
  general = C(P(1)^1),
  btrue = (P'true' * -1) / function() return true end,
  bfalse = (P'false' * -1) / function() return false end,
  zero = (P('0') * -1) / tonumber,
  value = V'zero' + integer_only + V'btrue' + V'bfalse' + V'general',
}
local process_quoted_value = function(text)
  return text:sub(2,-2)             -- remove the double-quotes that surround the text
end
local process_plain_value = function(text)
  return parsed_value:match(text)   -- 'true' becomes true, etc.
end
local kvlist = P({'kvlist',
  key = C(identifier),
  notcomma = P(1) - ',',
  notquote = P(1) - dquote,
  plain_val  = C((V'notcomma')^1) / process_plain_value,
  quoted_val = C(dquote * (V'notquote')^1 * dquote) / process_quoted_value,
  val = V'quoted_val' + V'plain_val',
  entry = Ct( Pos * hsp * V('key') * hsp * ('=' * hsp * V('val'))^-1 * hsp ) / tag('entry'),
  kvlist = Ct( V('entry') * (',' * V('entry'))^0 ) / process_kvlist
})
-- }}}

-- {{{ Comma-separated list (used in META values like SOURCES etc.)
-- local process_commalist = function(data)
-- end
local commalist = P({'commalist',
  -- TODO allow for quoted values so that commas can be used
  item = C( (P(1)-',')^1 ) / pl.stringx.strip,
  commalist = Ct( V('item') * (',' * V('item'))^0 )
})
-- }}}

-- {{{ Meaty parsing units, like opcode, argument, command0, command1, commandn
-- opcode is all upper case followed by optional star
--   (this will have to evolve, not least for environments)
local opcodechar = Upper + Digit
local opcode = Pos * C(Upper * opcodechar^0 * (P'*')^-1) / tag('opcode')
-- separator
local sep = space * '::' * hspace
-- end of command: end-of-text or (a newline with no separator following)
local endofcmd = -1 + (hsp * (nl * -#sep))
-- argument: all text until either a separator or endofcmd (just nl for now)
local notarg   = sep + nl
local argtext  = C((1 - notarg)^1)
-- verbatim argument .v << ...lines... >>
local endverbtext = nl * hsp * '>>'
local verbarg  = '.v <<' * hsp * nl *
                  (C((P(1) - endverbtext)^1) * endverbtext / tag('posarg'))
-- options argument
local optarg   = '.o' * hspace * argtext / tag('optarg')
-- keyword argument
local _key     = C(KeywordChar^1)
local _value   = argtext
local kwarg    = Ct('(' * _key * ')' * hspace * _value) / tag('kwarg')
-- positional argument can be ".a blah blah blah" but is more likely unadorned
local posarg   = ('.a' * hspace)^-1 * argtext / tag('posarg')
-- argument is any of the above specific argument types
local argument = Pos * (verbarg + optarg + kwarg + posarg)
-- command is split into 0, 1 or n arguments for ease of specification
local command0 = Ct(hsp * opcode * endofcmd)
local command1 = Ct(hsp * opcode * (sep + hspace) * argument * endofcmd)
local commandn = Ct(hsp * opcode * (sep + hspace) *
                      (argument * sep)^1 * argument * endofcmd)
-- }}}

-- {{{ Actual command processing
-- The "tagging" that gets done when an opcode or argument is parsed is useful
-- but crude. This function refines the data into something more usable.
local process_cmd = function(data)
  local result = { o = pl.Map(), k = pl.Map(), a = pl.List() }
  local seen = {}
  for _, x in pairs(data) do
    if x.type == 'opcode' then
      result[1] = x.value
    elseif x.type == 'optarg' then
      if seen.optarg or seen.kwarg or seen.posarg then return false end
      result.o = x.value                    -- raw string of kvlist
      result.o = kvlist:match(result.o)     -- parsed kvlist
      if result.o == nil then               --    which could be invalid
        return nil
      end
      seen.optarg = true
    elseif x.type == 'kwarg' then
      if seen.posarg then return false end
      local k, v = table.unpack(x.value)
      result.k[k] = v
      seen.kwarg = true
    elseif x.type == 'posarg' then
      result.a:append(x.value)
      seen.posarg = true
    end
  end
  return result
end
local command = (commandn + command1 + command0) / process_cmd * sp
local commands = Ct(command^1)

-- }}}

-- {{{ Overall document structure: [@META], [+BODY], and the whole document.
-- [@META] introduces a dictionary block
local process_dict_block = function(tags)
  local result = { type = 'dict_block' }
  local kvpattern = P'.d' * hspace * kvlist
  local listpattern = P'.l' * hspace * commalist
  result.name = tags[1].value
  result.entries = {}
  result.types = {}
  for i = 2,#tags do
    local key, value = table.unpack(tags[i].value)
    -- The value could be a kvlist, like 'OPTIONS .d vspace=12pt, color=blue'
    -- We want to extract this and store it as a map.
    local inline_kv = kvpattern:match(value)
    -- Or it could be a normal list, like 'SOURCES .l Exam, Questions'.
    local inline_list = listpattern:match(value)
    if inline_kv then
      result.entries[key] = inline_kv
      result.types[key] = 'dict'
    elseif inline_list then
      result.entries[key] = inline_list
      result.types[key] = 'list'
    else
      result.entries[key] = value
      result.types[key] = 'str'
    end
  end
  return result
end
local dictionary_block = P{ 'block',
  block = Ct(sp * V'header' * V'entry'^1) / process_dict_block,
  header = Pos * '[@' * (Upper^1 / tag('dict_header')) * ']' * hsp * nl,
  entry = Pos * Ct(hsp * C(V'key') * hspace * C(V'value') * nl) / tag('dict_entry'),
  key = Alpha^1,
  value = RestOfLine,
}

local list_header = Pos * '[+' * (Upper^1 / tag('list_header')) * ']' * hsp * nl * sp
local process_list_block = function(tags)
  return { type = 'list_block', name = tags[1].value, commands = tags[2] }
end
local list_block = Ct(sp * list_header * commands) / process_list_block

local block = dictionary_block + list_block
local document = Ct(block^1) * sp * -1
-- }}}

-- {{{ Test data

-- IN1: test the extraction of a series of commands
local IN1 = [[
  BEGIN multicols :: 2
  TEXT .o font=small :: Hello there
  END multicols
  VFILL
  ITEMIZE
    :: One
    :: Two
    :: Three
]]

-- IN2: test the extraction of a series of commands
local IN2 = [[
  TABLE .o float
    :: (caption) Phone directory
    :: (colspec) ll
    :: Name & Extension
    :: John & 429
    :: Mary & 388
  TEXT Hello
]]

-- IN3: test parsing of a series of commands containing an error
--  * Result: commands:match(IN3) works fine until and including the ITEMIZE line,
--    then it doesn't parse any more. So it silently ignores the remaining lines.
--    Modifying the parser to catch errors seems difficult. Best, I think, to
--    parse the whole document just one level deep, then get to work on the
--    command sequences. We can then check that we get it all.
local IN3 = [[
  TEXT .o font=small :: Error ahead
  VFILL
  ITEMIZE Warning - missing separators
    One
    Two
    Three
  TEXT Error above
]]

-- IN4: a META block
local IN4 = [[
  [@META]
    TEMPLATE Basic
    TRAIN    Bar :: Baz
    BUS      .d capacity=55, color=purple
    CAR      .d bool1 = false, bool2 = true, n1 = 56, n2 = -3, n3 = 0
    MOPED    .d slow
]]

-- IN5: a BODY block
local IN5 = [[
  [+BODY]
    TEXT A body block
    CLEARPAGE
]]

-- IN6: a complete document
local IN6 = [[
  [@META]
    TEMPLATE Basic
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
    MINTED python :: .v <<
      for name in names:
        print(f'Hello {name}')
      print('Done')
    >> :: foo
    TEXT Hello
]]

-- }}}

-- {{{ Testing
local test = function(patt)
  return patt * sp * P(-1)
end

local run_tests = function()
  local a = test(commands):match(IN1)
  local b = test(commands):match(IN2)
  local c = test(commands):match(IN3)   -- should be nil
  local d = test(dictionary_block):match(IN4)
  local e = test(list_block):match(IN5)
  local f = document:match(IN6)
  D(d)
end
-- run_tests()

-- }}}

-- {{{ Functions: fundamental parsing (parsed_content_0, parse_dictionary, parse_commands)

-- lbt.parser.parsed_content_0
--   * Does the actual parsing
--   * The text must not contain any pragmas
--   * Returns a list of document blocks, each one being of type 'dict_block'
--     or 'list_block'
--   * Further processing will be required to use the results:
--     - build an index of the contents   - incorporate pragmas
lbt.parser.parsed_content_0 = function(text)
  -- reset the file-scoped variable MaxPosition each time we do a parse
  MaxPosition = -1
  local pc0 = document:match(text)
  if pc0 then
    return { ok = true, pc0 = pc0 }
  else
    return { ok = false, maxposition = MaxPosition }
  end
end

-- lbt.parser.parse_dictionary
local dictionary_only = kvlist * hsp * -1
lbt.parser.parse_dictionary = function(s)
  return dictionary_only:match(s)
end

-- lbt.parser.parse_commands: necessary for commands like STO and DB that need to work with
-- LBT text and process it "at runtime".
lbt.parser.parse_commands = function(text)
  local CurrentMaxPosition = MaxPosition  -- store the global variable so we can reset it
  local pc0 = commands:match(text)
  MaxPosition = CurrentMaxPosition
  if pc0 then
    return { ok = true, commands = pl.List(pc0) }
  else
    return { ok = false }
  end
end

-- }}}

-- {{{ Functions: other parsing to support built-in templates
--
--   parse_ratio(n, text)
--   parse_align(n, text)
--
--   parse_ratio(2, '3.5:2') -> { 3.5, 2 }
--   parse_ratio(3, '3.5:2') -> error
--   set n = -1 to accept any number of parts

local ratio = P{'ratio',
  number = C(Digit^1 * ('.' * Digit^1)^0) / tonumber,
  part = V'number',
  sep = P':',
  ratio = Ct(V'part' * (V'sep' * V'part')^0 * -1)
}

lbt.parser.parse_ratio = function(n, text)
  local r = ratio:match(text)
  if not r then
    lbt.err.E002_general('Unable to parse ratio from <<%s>>', text)
  elseif #r == -1 or #r == n then
    return r
  else
    lbt.err.E002_general('Ratio <<%s>> is supposed to have %d parts', text, n)
  end
end

-- parse_align
--  * 'tbm' -> { 't', 'b', 'm' }
--  * 'tbx' -> error
--  * like parse_ratio, specify the expected #parts, or -1

local align = P{'align',
  letter = C(S'tmb'),
  align = Ct( (V'letter')^1 )
}

lbt.parser.parse_align = function(n, text)
  local a = align:match(text)
  if not a then
    lbt.err.E002_general('Unable to parse align spec from <<%s>>', text)
  elseif #a == -1 or #a == n then
    return a
  else
    lbt.err.E002_general('Align spec <<%s>> is supposed to have %d parts', text, n)
  end
end

-- parse_range
--  * '4..17'  -> 4, 17
--  * '6'      -> 6, 6
local range = P{'range',
  single = integer_only / function (x) return {x,x} end,
  double = Ct(integer * ('..' * integer)^-1 * -1),
  range  = V'single' + V'double'
}

lbt.parser.parse_range = function(text)
  local r = range:match(text)
  if not r then
    lbt.err.E002_general('Unable to parse range from text: "%s"', text)
  end
  return table.unpack(r)
end

-- parse_table_datarows
--  '@datarows 4..19'   -> {4, 19}
--  '@datarows 12'      -> {12, 12}
--  '@datarows xyz'     -> nil
--  'house'             -> nil
local datarows = P'@datarows' * hspace * range * -1

lbt.parser.parse_table_datarows = function(text)
  local r = datarows:match(text)
  return r or nil
end

-- }}}
