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
local V = lpeg.V
-- TODO examples

-- }}}

-- {{{ Fundamental parsing units, like space, position, tag function
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
-- alpha, digit and symbol
local Alpha = loc.alpha
local Digit = loc.digit
local Symbol = S'_.'
-- identifier can be like foo or foo_bar or foo.bar
local identifier = Alpha * (Alpha + Digit + Symbol)^1
-- }}}

-- {{{ Key-value list (used in optargs and possibly in META values etc.)
local process_kvlist = function(data)
  local result = {}
  for _, x in ipairs(data) do
    local k = x.value[1]
    local v = x.value[2] or true
    result[k] = v
  end
  return result
end
local kvlist = P({'kvlist',
  key = C(identifier),
  val = C( (P(1)-',')^1 ),
  entry = Ct( Pos * hsp * V('key') * hsp * ('=' * hsp * V('val'))^-1 * hsp ) / tag('entry'),
  kvlist = Ct( V('entry') * (',' * V('entry'))^0 ) / process_kvlist
})
-- }}}

-- {{{ Meaty parsing units, like opcode, argument, command0, command1, commandn
-- opcode is all upper case followed by optional star
--   (this will have to evolve, not least for environments)
local opcode = Pos * C(loc.upper^1 * (P'*')^-1) / tag('opcode')
-- separator
local sep = space * '::' * hspace
-- end of command: a newline with no separator following
local endofcmd = hsp * (nl * -#sep)
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
local _key     = C(loc.alpha^1)
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
  local result = { k = {}, a = pl.List() }
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
local command = (commandn + command1 + command0) / process_cmd
local commands = Ct(command^1)

-- }}}

-- {{{ Overall document structure: [@META], [+BODY], and the whole document.
-- [@META] introduces a dictionary block
local dict_header = Pos * '[@' * (loc.upper^1 / tag('dict_header')) * ']' * hsp * nl
local dict_key   = loc.alpha^1
local dict_value = (P(1) - nl)^1
local dict_entry = Pos * Ct(hsp * C(dict_key) * hspace * C(dict_value) * nl) / tag('dict_entry')
local process_dict_block = function(tags)
  local result = { type = 'dict_block' }
  result.name = tags[1].value
  result.entries = {}
  for i = 2,#tags do
    local key, value = table.unpack(tags[i].value)
    result.entries[key] = value
  end
  return result
end
local dict_block = Ct(sp * dict_header * dict_entry^1) / process_dict_block

local list_header = Pos * '[+' * (loc.upper^1 / tag('list_header')) * ']' * hsp * nl
local process_list_block = function(tags)
  return { type = 'list_block', name = tags[1].value, commands = tags[2] }
end
local list_block = Ct(sp * list_header * commands) / process_list_block

local block = dict_block + list_block
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
  return patt * sp * -1
end
local a = test(commands):match(IN1)
local b = test(commands):match(IN2)
local c = test(commands):match(IN3)   -- should be nil
local d = test(dict_block):match(IN4)
local e = test(list_block):match(IN5)
local f = document:match(IN6)
D(f)

-- }}}

-- {{{ Output of D(f) above, to demonstrate the result of parsing a whole document.
-- The output is simply pasted in here, for sake of example.
-- Note that the keys do not appear in a nice order.
-- I have added comments to break it up.
local output = {
  -- The META dictionary block. Note that the key-value information in BUS
  -- has not been parsed. Likewise the list information in TRAIN.
  {
    type = "dict_block",
    name = "META",
    entries = {
      BUS = ".d capacity=55, color=purple",
      TEMPLATE = "Basic",
      TRAIN = "Bar :: Baz"
    },
  },
  -- The BODY list block.
  {
    type = "list_block",
    name = "BODY",
    commands = {
      {
        "BEGIN",
        a = {
          "multicols",
          "2"
        },
        k = {
        }
      },
      {
        "TEXT",
        o = "font=small",
        a = {
          "Hello there"
        },
        k = {
        },
      },
      {
        "END",
        a = {
          "multicols"
        },
        k = {
        }
      },
      {
        "VFILL",
        a = {
        },
        k = {
        }
      },
      {
        "ITEMIZE",
        a = {
          "One",
          "Two",
          "Three"
        },
        k = {
        }
      }
    },
  },
  -- The EXTRA list block.
  {
    name = "EXTRA",
    type = "list_block",
    commands = {
      {
        "TABLE",
        a = {
          "Name & Extension",
          "John & 429",
          "Mary & 388"
        },
        k = {
          caption = "Phone directory",
          colspec = "ll"
        },
        o = "float"
      },
      {
        "MINTED",
        a = {
          "python",
          [[      for name in names:
        print(f'Hello {name}')
      print('Done')]],
          "foo"
        },
        k = {
        }
      },
      {
        "TEXT",
        a = {
          "Hello"
        },
        k = {
        }
      }
    },
  }
}

-- }}}

IX('done testing') -- exits the program
