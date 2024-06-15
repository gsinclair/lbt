--
-- We act on the global table `lbt` and populate its subtable `lbt.test`.
--

local EQ = pl.test.asserteq
local F = string.format
local nothing = "<nil>"

----------------------------------------------------------------------
-- vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
--      Experimental code: using lpeg to parse lbt document
-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
local lpeg = require 'lpeg'

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
-- TODO examples

local D = pl.pretty.dump


local T_parse_commands_lpeg = function()
  -- -P'a' matches anything except an a, and does not consume
  --       anything and cannot produce a capture
  -- -P'1' refuses to match anything, so can detect the end of string
  -- Put this together and we can search for a pattern p
  --   vowel = P'aeiou'
  --   const = loc.alpha - vowel
  --   needle = const * vowel * const
  --   haystack = 'I saw bob the other day'
  --   searchP = (1-needle)^0 * Cp() * needle
  -- Parse an assignment list like 'name=Tina, age =   42, married,'
  --   sp    = loc.space^0
  --   char  = loc.alpha + '_' + loc.digit
  --   word  = C(loc.alpha * char^0) * sp
  --   eq    = '=' * sp
  --   comma = ';' * sp
  --   assn  = word * (eq * word)^-1    // assignment
  --   list  = assn * (comma * assn)^0
  --   list  = sp * list^-1
  -- T_lpeg_6_parse_several_commands()
  T_lpeg_7_line_continuations()
end

T_lpeg_1 = function()
  local sp = loc.space^0
  local char = loc.alpha + '_' + loc.digit
  local word = C(loc.alpha * char^0) * sp
  local words2 = word * word
  local words3 = word * word * word
  local eq    = '=' * sp
  local comma = ',' * sp
  -- local assn  = word * (eq * word)^-1    // assignment
  -- local list  = assn * (comma * assn)^0
  -- list  = sp * list^-1
  DEBUGGER()
end

T_lpeg_2 = function()
  local inbox = {}

  local sp    = loc.space^0
  local space = loc.space^1
  -- token
  local cmd_char = loc.upper + loc.digit + S'-_*+=<>'
  local command = C(loc.upper * cmd_char^0)
  -- separator requires surrounding whitespace
  local separator = space * '::' * space
  -- general argument: leave the surrounding space for the separator
  local arg = (1 - separator)^1
  local argument = C(arg)

  local examples = pl.List()
  examples:append 'ITEMIZE one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five ::'
  examples:append 'ITEMIZE :: one :: two :: three four five :: ()'

  local command_line = command * (separator * argument)^0 * -1

  local n = 0
  for example in examples:iter() do
    n = n + 1
    print()
    print('Example ' .. n)
    print(example)
    local captures = { command_line:match(example) }
    D(captures)
  end

  -- DEBUGGER()
end

T_lpeg_3 = function()
  local sp    = loc.space^0
  local space = loc.space^1
  -- opcode
  local op_char = loc.upper + loc.digit + S'-_*+=<>'
  local opcode = C(loc.upper * op_char^0)
  -- separator requires surrounding whitespace
  local separator = space * '::' * (space + -1)
  -- general argument: leave the surrounding space for the separator
  local argument = C( (1 - separator)^1 )

  -- A command with no arguments is a plain opcode.
  local command0 = opcode * -1
  -- A command with one argument contains an optional separator.
  local command1 = opcode * separator^-1 * sp * argument * -1
  -- A command with n arguments has the optional separator, then
  -- the first argument, then at least one separator-argument pair
  local commandn = opcode * separator^-1 * sp * argument *
                     (separator * argument)^1 * -1

  local command = command0 + command1 + commandn

  local examples = pl.List()
  examples:append 'VFILL'
  examples:append 'VFILL :: '
  examples:append 'VFILL :: ()'
  examples:append 'CMD bigskip'
  examples:append 'CMD :: bigskip'
  examples:append 'ITEMIZE one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five ::'
  examples:append 'ITEMIZE :: one :: two :: three four five :: ()'

  local n = 0
  for example in examples:iter() do
    n = n + 1
    print()
    print('Example ' .. n)
    print(example)
    local captures = { command:match(example) }
    D(captures)
  end

end

T_lpeg_4 = function()
  -- `inbox` is where we collect data as we parse
  inbox = {}

  -- functions that collect data
  process_opcode = function(x)
    return { opcode = x }
  end
  process_options = function(x)
    return { options = x }
  end
  process_kwarg = function(k, v)
    return { kwarg = {k,v} }
  end
  process_arg = function(x)
    if x == '()' then
      return nil
    else
      return { arg = x }
    end
  end

  -- sp = optional space; space = compulsory space
  local sp    = loc.space^0
  local space = loc.space^1
  -- list: name = john, age= 42 , red,11
  --   --> { kw = { name = 'john', age = '42' }, pos = { 'red', '11' } }

  -- opcode
  local op_char = loc.upper + loc.digit + S'-_*+=<>'
  local opcode = (loc.upper * op_char^0) / process_opcode
  -- separator requires surrounding whitespace
  local separator = space * '::' * (space + -1)
  -- general argument: leave the surrounding space for the separator
  local argument_text = (1 - separator)^1 
  local argument = argument_text / process_arg
  -- options (also called styles) can be specified in three equivalent
  -- ways: .o {list}  or .s {list}  or  [{list}]
  local options1 = P'.o' * space * (argument_text / process_options)
  local options2 = P'.s' * space * (argument_text / process_options)
  local options3 = P'[' * (argument_text / process_options) * ']'
  local options  = options1 + options2 + options3
  -- a keyword argument is specified like the following example.
  --     FIGURE .o centre
  --       :: .a (filename) media/7/primenumbers.png
  --       :: .a (width)    0.8
  --       :: .a (caption)  The numbers 1 to 100, with primes circled
  local key = '(' * C(loc.alpha^1) * ')'
  local value = C(argument_text)
  local kw_arg = P'.a' * space * (key * value) / process_kwarg

  -- A command with no arguments is a plain opcode.
  local command0 = opcode * -1
  -- A command with one argument contains an optional separator.
  local command1 = opcode * separator^-1 * sp * argument * -1
  -- A command with n arguments has the optional separator, then perhaps an
  -- "options" argument, then at least one separator-argument pair.
  local commandn = opcode * separator^-1 * sp *
                     (options * separator)^-1 *
                     argument * (separator * argument)^1 * -1
  local commandn = opcode * separator^-1 * sp *
                     (options * separator)^-1 *
                     (kw_arg * sep) *
                     argument * (separator * argument)^1 * -1

  local command = command0 + command1 + commandn

  local examples = pl.List()
  -- examples:append 'VFILL'
  -- examples:append 'VFILL :: '
  -- examples:append 'VFILL :: ()'
  -- examples:append 'CMD bigskip'
  -- examples:append 'CMD :: bigskip'
  examples:append 'ITEMIZE one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five ::'
  examples:append 'ITEMIZE :: one :: two :: three four five :: ()'
  examples:append 'ITEMIZE :: .o compact :: one :: two'
  examples:append 'FIGURE .o centre :: .a (filename) media/7/primenumbers.png :: .a (width)    0.8 :: .a (caption)  The numbers 1 to 100, with primes circled :: normal argument'

  local n = 0
  for example in examples:iter() do
    n = n + 1
    print()
    print('Example ' .. n)
    print(example)
    local captures = { command:match(example) }
    D(captures)
  end

end

-- (9 June 2024) T_lpeg_5 is a successful experiment in parsing commands. There
-- is some finessing to do, like using .k instead of .a for keyword arguments, and
-- using .a for positional arguments. But T_lpeg_5 carried on with the assumption,
-- present since forever, that a command will always be presented as a single
-- line (i.e. the source will use » if multiple lines are desired, but lbt will
-- take care of that before command processing). I now want to experiment with
-- using lpeg to detect whole multi-line commands, and allow multi-line arguments
-- with `[[ ... ]]`.
T_lpeg_5 = function()
  -- `cmd` is where we collect data as we parse
  cmd = {}

  -- functions that collect data
  process_opcode = function(x)
    cmd['opcode'] = x
    cmd['cmdtype'] = 'command'
    if x[1] == '+' then cmd['cmdtype'] = 'env-open' end
    if x[1] == '-' then cmd['cmdtype'] = 'env-close' end
    if x[1] == '+' or x[1] == '-' then cmd['env'] = sub(x,2) end
    return nil
  end
  process_options = function(x)
    return { options = x }
  end
  process_kwarg = function(k, v)
    return { kwarg = {k,v} }
  end
  process_arg = function(x)
    if x == '()' then
      return nil
    else
      return { arg = x }
    end
  end

  -- sp = optional space; space = compulsory space
  local sp    = loc.space^0
  local space = loc.space^1
  -- opcode
  local op_char = loc.upper + loc.digit + S'-_*+=<>'
  local opcode = ((S'+-')^-1 * loc.upper * op_char^0) / process_opcode
  -- separator requires surrounding whitespace
  local sep = space * '::' * (space + -1)
  -- non-separator text is a building block for capturing various arguments
  local textnonsep = C((1 - sep)^1 )

  -- A command with no arguments is a plain opcode.
  local command0 = opcode * -1
  -- A command with at least one argument has an optional separator
  -- to begin with.
  local commandn = opcode * (sep + space) * C(P(1)^1) * -1

  -- parse_command_1 extracts opcode and argtext, and that is all.
  -- The argtext is guaranteed not to start with a separator.
  -- Returns (true, opcode, argtext) or (false, nil, nil).
  local parse_command_1 = function(line)
    local op_char = loc.upper + loc.digit + S'-_*+=<>'
    local opcode = C((S'+-')^-1 * loc.upper * op_char^0)
    local rest = C(P(1)^1)
    local command1 = opcode * sp * -1
    local commandn = opcode * sep^-1 * sp * rest * -1
    local command = command1 + commandn
    local captures = {command:match(line)}
    if captures[1] then
      return true, captures[1], captures[2]
    else
      return false, nil, nil
    end
  end

  -- parse_command_2 processes the argtext into options, kwargs, posargs.
  -- It returns a collection of tables like the following:
  --   { type = 'options', value = 'compact, format=(i)' }
  --   { type = 'kwarg',   key = 'filename', value = 'media/xyz.png' }
  --   { type = 'posarg',  value = 'In this article we examine...'}
  -- The options need further processing. Delaying that until later allows
  -- for better error messages.
  local parse_command_2 = function(argtext)
    if argtext == nil then
      return pl.List({})
    end

    -- First prepend a separator to argtext so that it is in a standard
    -- format.
    argtext = ' :: ' .. argtext

    local proc_opt = function(x)
      return { type = 'options', value = x }
    end
    local proc_kwarg = function(k, v)
      return { type = 'kwarg', key = k, value = v }
    end
    local proc_posarg = function(x)
      if x == '()' then return nil end
      return { type = 'posarg', value = x }
    end

    -- options (also called styles) can be specified in three equivalent
    -- ways: .o {list}  or .s {list}  or  [{list}]
    local options1 = P'.o' * space * textnonsep
    local options2 = P'.s' * space * textnonsep
    local options3 = P'[' * textnonsep * ']'
    local options  = (options1 + options2 + options3) / proc_opt

    -- a keyword argument is specified like the following example.
    --     FIGURE .o centre
    --       :: .a (filename) media/7/primenumbers.png
    --       :: .a (width)    0.8
    --       :: .a (caption)  The numbers 1 to 100, with primes circled
    local key = '(' * C(loc.alpha^1) * ')' * space
    local value = C(textnonsep)
    local kw_arg = ( P'.a' * space * (key * value) ) / proc_kwarg
    --
    -- general (positional) argument has no particular format
    local argument = textnonsep / proc_posarg

    -- arguments must appear in a certain order
    -- local arguments = (sep * options)^-1 * (sep * kw_arg)^0 * (sep * argument)^0 * -1
    -- 
    -- Actually, I decided it's better to just accept argument types in any
    -- order, and deal with errors later.
    local arguments = (sep * (options + kw_arg + argument))^1

    local results = { arguments:match(argtext) }
    return pl.List(results)
  end

  -- parse_command_3 takes the output of _2, plus the opcode, and creates a
  -- full command object. Example output:
  --
  --   { cmdtype = 'command'
  --     opcode  = 'FIGURE'
  --     options = { 'center',
  --                 center = true, border = '1pt',
  --                 _text = 'centre, border=1pt' }
  --     args    = { 'a positional argument'
  --                 filename = 'media/xyz.png'
  --                 width    = '0.8'
  --                 caption  = 'A male seal with his cubs' } }
  --
  local parse_command_3 = function(opcode, argdetails)
    local command = {}
    command.cmdtype = 'command'  -- may be overwritten to 'env-{open,close}'
    command.opcode  = opcode
    command.options = pl.OrderedMap()
    command.args    = pl.List()
    if opcode[1] == '+' then
      command.cmdtype = 'env-open'
    elseif opcode[1] == '-' then
      command.cmdtype = 'env-close'
    end
    local errors = pl.List()
    local seen_opt, seen_kw, seen_pos = false, false, false
    for a in argdetails:iter() do
      if a.type == 'options' then
        if seen_opt then
          errors:append('more than one options argument')
        elseif seen_kw or seen_pos then
          errors:append('options argument must appear first')
        else
          command.options.text_ = a.value
          -- TODO now parse the option argument, flag any errors, and
          -- update the command object
        end
        seen_opt = true
      end
      if a.type == 'kwarg' then
        if seen_pos then
          errors:append('keyword argument appears after positional argument')
        else
          command.args[a.key] = a.value
        end
        seen_kw = true
      end
      if a.type == 'posarg' then
        command.args:append(a.value)
        seen_pos = true
      end
    end
    -- TODO return errors and command
    return errors, command
  end

  local examples = pl.List()
  examples:append 'VFILL'
  examples:append 'VFILL    '
  examples:append 'VFILL :: '
  examples:append 'VFILL :: ()'
  examples:append 'CMD bigskip'
  examples:append 'CMD :: bigskip'
  examples:append 'ITEMIZE one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five'
  examples:append 'ITEMIZE :: one :: two :: three four five ::'
  examples:append 'ITEMIZE :: one :: two :: three four five :: ()'
  examples:append 'ITEMIZE :: .o compact :: one :: two'
  examples:append 'FIGURE .o centre :: .a (filename) media/7/primenumbers.png :: .a (width)    0.8 :: .a (caption)  The numbers 1 to 100, with primes circled :: normal argument'
  examples:append 'FIGURE .o centre :: .a (filename) media/7/primenumbers.png :: .a (width)    0.8 :: positional argument :: .a (caption)  The numbers 1 to 100, with primes circled'

  local n = 0
  for example in examples:iter() do
    n = n + 1
    print()
    print('Example ' .. n)
    print(example)
    local ok, opcode, argtext = parse_command_1(example)
    if not ok then
      print('failed parse_command_1')
      goto continue
    end
    local argdetails = parse_command_2(argtext)
    local errors, command = parse_command_3(opcode, argdetails)
    if #errors == 0 then
      D(command)
    else
      print 'Error(s) encountered while processing arguments:'
      for e in errors:iter() do
        print('  * ' .. e)
      end
    end
    ::continue::
  end

end

-- (9 June 2024) See comment for T_lpeg_5.
T_lpeg_6_parse_several_commands = function()
  -- {{{
  -- `cmd` is where we collect data as we parse
  cmd = {}

  -- functions that collect data
  process_opcode = function(x)
    cmd['opcode'] = x
    cmd['cmdtype'] = 'command'
    if x[1] == '+' then cmd['cmdtype'] = 'env-open' end
    if x[1] == '-' then cmd['cmdtype'] = 'env-close' end
    if x[1] == '+' or x[1] == '-' then cmd['env'] = sub(x,2) end
    return nil
  end
  process_options = function(x)
    return { options = x }
  end
  process_kwarg = function(k, v)
    return { kwarg = {k,v} }
  end
  process_arg = function(x)
    if x == '()' then
      return nil
    else
      return { arg = x }
    end
  end

  -- sp = optional space; space = compulsory space
  local sp    = loc.space^0
  local space = loc.space^1
  -- opcode
  local op_char = loc.upper + loc.digit + S'-_*+=<>'
  local opcode = ((S'+-')^-1 * loc.upper * op_char^0) / process_opcode
  -- separator requires surrounding whitespace
  local sep = space * '::' * (space + -1)
  -- non-separator text is a building block for capturing various arguments
  local textnonsep = C((1 - sep)^1 )

  -- A command with no arguments is a plain opcode.
  local command0 = opcode * -1
  -- A command with at least one argument has an optional separator
  -- to begin with.
  local commandn = opcode * (sep + space) * C(P(1)^1) * -1

  -- parse_command_1 extracts opcode and argtext, and that is all.
  -- The argtext is guaranteed not to start with a separator.
  -- Returns (true, opcode, argtext) or (false, nil, nil).
  local parse_command_1 = function(line)
    local op_char = loc.upper + loc.digit + S'-_*+=<>'
    local opcode = C((S'+-')^-1 * loc.upper * op_char^0)
    local rest = C(P(1)^1)
    local command1 = opcode * sp * -1
    local commandn = opcode * sep^-1 * sp * rest * -1
    local command = command1 + commandn
    local captures = {command:match(line)}
    if captures[1] then
      return true, captures[1], captures[2]
    else
      return false, nil, nil
    end
  end

  -- parse_command_2 processes the argtext into options, kwargs, posargs.
  -- It returns a collection of tables like the following:
  --   { type = 'options', value = 'compact, format=(i)' }
  --   { type = 'kwarg',   key = 'filename', value = 'media/xyz.png' }
  --   { type = 'posarg',  value = 'In this article we examine...'}
  -- The options need further processing. Delaying that until later allows
  -- for better error messages.
  local parse_command_2 = function(argtext)
    if argtext == nil then
      return pl.List({})
    end

    -- First prepend a separator to argtext so that it is in a standard
    -- format.
    argtext = ' :: ' .. argtext

    local proc_opt = function(x)
      return { type = 'options', value = x }
    end
    local proc_kwarg = function(k, v)
      return { type = 'kwarg', key = k, value = v }
    end
    local proc_posarg = function(x)
      if x == '()' then return nil end
      return { type = 'posarg', value = x }
    end

    -- options (also called styles) can be specified in three equivalent
    -- ways: .o {list}  or .s {list}  or  [{list}]
    local options1 = P'.o' * space * textnonsep
    local options2 = P'.s' * space * textnonsep
    local options3 = P'[' * textnonsep * ']'
    local options  = (options1 + options2 + options3) / proc_opt

    -- a keyword argument is specified like the following example.
    --     FIGURE .o centre
    --       :: .a (filename) media/7/primenumbers.png
    --       :: .a (width)    0.8
    --       :: .a (caption)  The numbers 1 to 100, with primes circled
    local key = '(' * C(loc.alpha^1) * ')' * space
    local value = C(textnonsep)
    local kw_arg = ( P'.a' * space * (key * value) ) / proc_kwarg
    --
    -- general (positional) argument has no particular format
    local argument = textnonsep / proc_posarg

    -- arguments must appear in a certain order
    -- local arguments = (sep * options)^-1 * (sep * kw_arg)^0 * (sep * argument)^0 * -1
    -- 
    -- Actually, I decided it's better to just accept argument types in any
    -- order, and deal with errors later.
    local arguments = (sep * (options + kw_arg + argument))^1

    local results = { arguments:match(argtext) }
    return pl.List(results)
  end

  -- parse_command_3 takes the output of _2, plus the opcode, and creates a
  -- full command object. Example output:
  --
  --   { cmdtype = 'command'
  --     opcode  = 'FIGURE'
  --     options = { 'center',
  --                 center = true, border = '1pt',
  --                 _text = 'centre, border=1pt' }
  --     args    = { 'a positional argument'
  --                 filename = 'media/xyz.png'
  --                 width    = '0.8'
  --                 caption  = 'A male seal with his cubs' } }
  --
  local parse_command_3 = function(opcode, argdetails)
    local command = {}
    command.cmdtype = 'command'  -- may be overwritten to 'env-{open,close}'
    command.opcode  = opcode
    command.options = pl.OrderedMap()
    command.args    = pl.List()
    if opcode[1] == '+' then
      command.cmdtype = 'env-open'
    elseif opcode[1] == '-' then
      command.cmdtype = 'env-close'
    end
    local errors = pl.List()
    local seen_opt, seen_kw, seen_pos = false, false, false
    for a in argdetails:iter() do
      if a.type == 'options' then
        if seen_opt then
          errors:append('more than one options argument')
        elseif seen_kw or seen_pos then
          errors:append('options argument must appear first')
        else
          command.options.text_ = a.value
          -- TODO now parse the option argument, flag any errors, and
          -- update the command object
        end
        seen_opt = true
      end
      if a.type == 'kwarg' then
        if seen_pos then
          errors:append('keyword argument appears after positional argument')
        else
          command.args[a.key] = a.value
        end
        seen_kw = true
      end
      if a.type == 'posarg' then
        command.args:append(a.value)
        seen_pos = true
      end
    end
    -- TODO return errors and command
    return errors, command
  end
  -- }}}

  -- parse6: split text into commands. Return a simple list of command texts.
  local parse6 = function (text)
    -- -- sp = optional space; space = compulsory space
    -- local sp    = loc.space^0
    -- local space = loc.space^1
    -- -- opcode
    -- local op_char = loc.upper + loc.digit + S'-_*+=<>'
    -- local opcode = ((S'+-')^-1 * loc.upper * op_char^0)
    -- -- separator requires surrounding whitespace
    -- local sep = space * '::' * (space + -1)
    -- -- non-separator text is a building block for capturing various arguments
    -- local textnonsep = C((1 - sep)^1 )
    --
    -- -- A command with no arguments is a plain opcode.
    -- local command0 = opcode * -1
    -- -- A command with at least one argument has an optional separator
    -- -- to begin with.
    -- local commandn = opcode * (sep + space) * C(P(1)^1) * -1

    local sp = (S' \t')^0
    local space = (S' \t')^1
    local nl = P'\n'
    local opcode = sp * (loc.upper^1 * (P'*')^-1)    -- simple opcode for now
    local sep = space * '::' * space
    -- end of command: a newline with no separator following
    local endofcmd = sp * (nl - #sep)
    -- argument: all text until either a separator or endofcmd
    local argument = (1 - (sep + endofcmd))^1
    local command0 = C(opcode) * endofcmd
    local command1 = opcode * argument * endofcmd
    local commandn = opcode * (sep * argument)^1 * endofcmd
    local command = commandn + command1 + commandn
    local commands = command^1
    DEBUGGER()
    return commands:match(text)
  end

  local examples = pl.List()
  -- 1
  examples:append [[
    CLEARPAGE
  ]]
  -- 2
  examples:append [[
    VSPACE 3em
  ]]
  -- 3
  examples:append [[
    VSPACE 3em :: Hello :: Goodbye
  ]]
  -- 4
  examples:append [[
    TEXT
      :: Hello
  ]]
  -- 5
  examples:append [[
    ITEMIZE
      :: The rain in Spain falls mainly on the plane.
      :: The quick brown fox jumps over the lazy dog.
      :: Now is the time for all good men to come to the aid of the party.
  ]]
  -- 6
  examples:append [[
    ITEMIZE .o compact, topsep=12pt
      :: The rain in Spain falls mainly on the plane.
      :: The quick brown fox jumps over the lazy dog.
      :: Now is the time for all good men to come to the aid of the party.
  ]]
  -- 7
  examples:append [[
    CLEARPAGE
    VSPACE 3em
  ]]
  -- 8
  examples:append [[
    CLEARPAGE
    VSPACE 3em
    FIGURE .o centre
      :: (filename) media/7/primenumbers.png
      :: (width)    0.8
      :: .k (caption)  The numbers 1 to 100, with primes circled
      :: normal argument
    CMD bigskip
    TEXT .o vspace=12pt :: Hello one two three.
     » Four five six.
    ]]

  -- <experiment>
  local tag = function(type)
    return function(x)
      return { type = type, value = x }
    end
  end
  local pos = Cp() / tag('position')
  local sp = (S' \t')^0
  local allsp = (S' \t\n')^0
  local space = (S' \t')^1
  local allspace = (S' \t\n')^1
  local nl = P'\n'
  local opcode = C(loc.upper^1 * (P'*')^-1) / tag('opcode')
  local sep = allspace * '::' * space
  -- end of command: a newline with no separator following
  local endofcmd = sp * (nl * -#sep)
  -- argument: all text until either a separator or endofcmd (just nl for now)
  local notarg   = sep + nl
  local argument = C((1 - notarg)^1) / tag('rawarg')
  local command0 = Ct(sp * opcode * endofcmd * pos)
  local command1 = Ct(sp * opcode * (sep + space) * argument * endofcmd * pos)
  local commandn = Ct(sp * opcode * (sep + space) * (argument * sep)^1 * argument * endofcmd * pos)
  local process_cmd = function(data)
    local result = { rawargs = pl.List() }
    for _, x in pairs(data) do
      if x.type == 'opcode' then
        result.opcode = x.value
      elseif x.type == 'rawarg' then
        result.rawargs:append(x.value)
      elseif x.type == 'position' then
        result.position = x.value
      end
    end
    return result
  end
  local command = ((commandn + command1 + command0)) / process_cmd
  local commands = Ct(command^1)

  local patterns = { command0 = command0, command1 = command1, commandn = commandn, command = command, commands = commands }
  local e1, e2, e3, e4, e5, e6, e7, e8 = table.unpack(examples)

  local test = function(pattern_name, text)
    print()
    print('------- ' .. pattern_name)
    print(text)
    local m = patterns[pattern_name]:match(text)
    D(m)
  end

  -- local p = Ct(sp * opcode * pos )
  -- D(p:match(e1))

  test('command', e1)
  test('command', e2)
  test('command', e3)
  test('command', e4)
  test('command', e5)
  test('command', e6)

  -- Now for multiple commands
  print('============================================================')
  local extract_commands = function(text)
    local length = #text
    local position = 1
    local result = pl.List()
    local done = false
    repeat
      local cmd = command:match(text, position)
      if cmd ~= nil then
        result:append(cmd)
        position = cmd.position
      else
        done = true
      end
    until done
    return result
  end
  test_multi = function(text)
    local x = extract_commands(text)
    print()
    print('---------')
    print(text)
    D(x)
  end
  test_multi(e7)
  test_multi(e8)

end

T_lpeg_7_line_continuations = function()
  local example = [[
    TEXT I'm the cat in the hat, and I'm »
      glad that I found you.
      » Your mother would not mind at all »
      if I »
      » do.
  ]]

  local x = example
  print(x)
  x = x:gsub('»[ \t]*\n[ \t]*»', '')
  print(x)
  x = x:gsub('»[ \t]*\n[ \t]*', '')
  print(x)
  x = x:gsub('[ \t]*\n[ \t]*»', '')
  print(x)
end

----------------------------------------------------------------------

local function content_lines(text)
  return pl.List(pl.utils.split(text, "\n")):map(string.strip)
end

-- Whip up a parsed token thing for testing
local T = function(t, n, a)
  return { token = t, nargs = n, args = pl.List(a) }
end

----------------------------------------------------------------------

-- For testing parsed_content
local good_input_1 = content_lines([[
  !DRAFT
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
    ITEMIZE  [topsep=0pt] :: Bear :: Chameleon :: Frog
    TEXT* 30pt :: Have you seen any of these?]])

-- For testing negative expansion of Basic template
local bad_input_1 = content_lines([[
  [@META]
    TEMPLATE lbt.Basic
  [+BODY]
    TEXT
    TEXT a :: b :: c
    ITEMIZE
    XYZ foo bar]])

-- For testing styles (no local override)
local good_input_5a = content_lines([[
  [@META]
    TEMPLATE TestQuestions
  [+BODY]
    TEXT 30pt :: Complete these questions in the space below.
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
    STYLES   Q.vspace 18pt :: MC.alphabet roman
  [+BODY]
    TEXT 30pt :: Complete these questions in the space below.
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

----------------------------------------------------------------------

local function T_pragmas_and_other_lines()
  lbt.api.reset_global_data()
  local input = pl.List.new{"!DRAFT", "Line 1", "!IGNORE", "Line 2", "Line 3"}
  local pragmas, lines = lbt.fn.impl.pragmas_and_other_lines(input)
  EQ(pragmas, { draft = true, ignore = true, debug = false })
  EQ(lines, pl.List.new({"Line 1", "Line 2", "Line 3"}))
end

-- XXX In the process of updating, June 2024.
-- !DRAFT
-- [@META]
--   TEMPLATE Basic
--   TRAIN    Bar :: Baz
--   BUS      .d capacity=55, color=purple
-- [+BODY]
--   BEGIN multicols :: 2
--   TEXT .o font=small :: Hello there
--   END multicols
--   VFILL
--   ITEMIZE
--     :: One
--     :: Two
--     :: Three
-- [+EXTRA]
--   TABLE .o float
--     :: (caption) Phone directory
--     :: (colspec) ll
--     :: Name & Extension
--     :: John & 429
--     :: Mary & 388
--   TEXT Hello

-- This uses good_input_1 to test lbt.fn.parsed_content.
local function T_parsed_content_1()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content(good_input_1)
  -- check pragams are correct
  local exp_pragmas = { draft = true, debug = false, ignore = false }
  -- check META is correct
  EQ(pc.pragmas, exp_pragmas)
  local exp_meta = {
    type = 'dictionary-block',
    name = 'META',
    data = {
      TEMPLATE = { n = 1, types = 's',  args = { 'Basic' } },
      TRAIN    = { n = 2, types = 'ss', args = { 'Bar', 'Baz' } },
      BUS      = { n = 1, types = 'd',  args = { { capacity = '55', color = 'purple' } } }
    }
  }
  EQ(pc.dict.META, exp_meta)
  -- check BODY is correct
  local exp_body = {
    { opcode = 'BEGIN', options = {}, kwargs = {}, args = {'multicols', '2'} },
    { opcode = 'TEXT', options = {font='small'}, kwargs = {}, args = {'Hello there'} },
    { opcode = 'END', options = {}, kwargs = {}, args = {'multicols'} },
    { opcode = 'VFILL', options = {}, kwargs = {}, args = {} },
    { opcode = 'ITEMIZE', options = {}, kwargs = {}, args = {'One', 'Two', 'Three'} },
  }
  EQ(pc.list.BODY[1], exp_body[1])
  EQ(pc.list.BODY[2], exp_body[2])
  EQ(pc.list.BODY[3], exp_body[3])
  EQ(pc.list.BODY[4], exp_body[4])
  EQ(pc.list.BODY[5], exp_body[5])
  EQ(pc.list.BODY[6], exp_body[6])
  EQ(pc.list.BODY[7], exp_body[7])
  EQ(pc.list.BODY,    exp_body)
  -- check EXTRA is correct
  local exp_extra = {
    { opcode = 'TABLE', options = {float=true},
      kwargs = {caption='Phone directory', colspec='ll'},
      args = {'Name & Extension', 'John & 429', 'Mary & 388'} },
    { opcode = 'TEXT', options = {}, kwargs = {}, args = {'Hello'} },
  }
  EQ(pc.list.EXTRA[1], exp_extra[1])
  EQ(pc.list.EXTRA[2], exp_extra[2])
  EQ(pc.list.EXTRA,    exp_extra)
end

local function T_extra_sources()
  lbt.api.reset_global_data()
  -- We assume parsed_content works for these inputs.
  local pc2 = lbt.fn.parsed_content(good_input_2)
  local pc3 = lbt.fn.parsed_content(good_input_3)
  local s2  = lbt.fn.pc.extra_sources(pc2)
  local s3  = lbt.fn.pc.extra_sources(pc3)
  assert(s2 == pl.List{"Questions", "Figures", "Tables"})
  assert(s3 == pl.List{})
end

local function T_add_template_directory()
  lbt.api.reset_global_data()
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
  lbt.api.reset_global_data()
  lbt.fn.template_register_to_logfile()
  local pc = lbt.fn.parsed_content(good_input_4)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  EQ(l[1], [[Examples of animals: \par]])
  assert(l[2]:lfind("\\item Bear"))
  assert(l[2]:lfind("\\item Chameleon"))
  assert(l[2]:lfind("\\item Frog"))
  EQ(l[3], [[\vspace{30pt} Have you seen any of these?]])
end

local function T_expand_Basic_template_2()
  lbt.api.reset_global_data()
  lbt.fn.template_register_to_logfile()
  local pc = lbt.fn.parsed_content(bad_input_1)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  assert(l[1]:lfind([[Token \verb|TEXT| raised error]]))
  assert(l[1]:lfind([[0 args given but 1-2 expected]]))
  assert(l[2]:lfind([[Token \verb|TEXT| raised error]]))
  assert(l[2]:lfind([[3 args given but 1-2 expected]]))
  assert(l[3]:lfind([[Token \verb|ITEMIZE| raised error]]))
  assert(l[3]:lfind([[0 args given but 1+ expected]]))
  assert(l[4]:lfind([[Token \verb|XYZ| not resolved]]))
end

local function T_util()
  lbt.api.reset_global_data()
  -- Splitting text
  EQ(lbt.util.double_colon_split('a :: b :: c'), {'a', 'b', 'c'})
  EQ(lbt.util.space_split('a b c'),    {'a', 'b', 'c'})
  EQ(lbt.util.space_split('a b c', 2), {'a', 'b c'})
  EQ(lbt.util.comma_split('one,two   ,     three'), {'one','two','three'})
end

local function T_template_styles_specification()
  lbt.api.reset_global_data()
  local input = { Q  = { vspace = '12pt', color = 'blue' },
                  MC = { alphabet = 'roman' } }
  local expected = { ['Q.vspace'] = '12pt', ['Q.color'] = 'blue',
                     ['MC.alphabet'] = 'roman' }
  local ok, output = lbt.fn.impl.template_styles_specification(input)
  assert(ok)
  EQ(output, expected)
end

local function T_number_in_alphabet()
  lbt.api.reset_global_data()
  local f = lbt.util.number_in_alphabet
  EQ(f(15, 'latin'), 'o')
  EQ(f(15, 'Latin'), 'O')
  EQ(f(15, 'roman'), 'xv')
  EQ(f(15, 'Roman'), 'XV')
end

local function T_style_string_to_map()
  local text = "Q.vspace 30pt :: Q.color navy :: MC.alphabet latin"
  local map  = lbt.fn.style_string_to_map(text)
  EQ(map, { ["MC.alphabet"] = "latin", ["Q.color"] = "navy", ["Q.vspace"] = "30pt" })
end

-- In this test, we do not add any global styles, but we do add local ones
local function T_style_resolver_1a()
  lbt.api.reset_global_data()
  lbt.api.add_template_directory("PWD/templates")
  -- This is inside baseball, but it is necessary setup for a style resolver.
  local pc = lbt.fn.parsed_content(good_input_5b)
  local _, sr = lbt.fn.token_and_style_resolvers(pc)
  -- We are now ready to test.
  EQ(sr('Q.vspace'), '18pt')        -- local
  EQ(sr('Q.color'), 'blue')         -- default
  EQ(sr('QQ.alphabet'), 'latin')    -- default
  EQ(sr('MC.alphabet'), 'roman')    -- local
end

-- In this test, we add both global and local styles
local function T_style_resolver_1b()
  lbt.api.reset_global_data()
  lbt.api.add_styles("Q.vspace 30pt :: Q.color navy :: MC.alphabet roman")
  lbt.api.add_template_directory("PWD/templates")
  -- This is inside baseball, but it is necessary setup for a style resolver.
  local pc = lbt.fn.parsed_content(good_input_5b)
  local _, sr = lbt.fn.token_and_style_resolvers(pc)
  -- We are now ready to test.
  EQ(sr('Q.vspace'), '18pt')        -- local
  EQ(sr('Q.color'), 'navy')         -- global
  EQ(sr('QQ.alphabet'), 'latin')    -- default
  EQ(sr('MC.alphabet'), 'roman')    -- local
end

local function T_styles_in_test_question_template_5a()
  lbt.api.reset_global_data()
  lbt.api.add_template_directory("PWD/templates")
  local pc = lbt.fn.parsed_content(good_input_5a)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  EQ(l[1], [[\vspace{30pt} Complete these questions in the space below. \par]])
  EQ(l[2], [[{\vspace{12pt}
              \bsferies\color{blue}Question~1}\enspace Evaluate:]])
  EQ(l[3], [[(a)~$2+2$]])
  EQ(l[4], [[(b)~$5 \times 6$]])
  EQ(l[5], [[(c)~$\exp(i\pi)$]])
  EQ(l[6], [[{\vspace{12pt}
              \bsferies\color{blue}Question~2}\enspace Which is a factor of $x^2 + 6x + 8$?]])
  EQ(l[7], [[(MC A) \quad $x+1$\\
(MC B) \quad $x+2$\\
(MC C) \quad $x+3$\\
(MC D) \quad $x+4$\\]])
  EQ(l[8], nil)
end

local function T_styles_in_test_question_template_5b()
  lbt.api.reset_global_data()
  lbt.api.add_template_directory("PWD/templates")
  local pc = lbt.fn.parsed_content(good_input_5b)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  EQ(l[1], [[\vspace{30pt} Complete these questions in the space below. \par]])
  EQ(l[2], [[{\vspace{18pt}
              \bsferies\color{blue}Question~1}\enspace Evaluate:]])
  EQ(l[3], [[(a)~$2+2$]])
  EQ(l[4], [[(b)~$5 \times 6$]])
  EQ(l[5], [[(c)~$\exp(i\pi)$]])
  EQ(l[6], [[{\vspace{18pt}
              \bsferies\color{blue}Question~2}\enspace Which is a factor of $x^2 + 6x + 8$?]])
  EQ(l[7], [[(MC i) \quad $x+1$\\
(MC ii) \quad $x+2$\\
(MC iii) \quad $x+3$\\
(MC iv) \quad $x+4$\\]])
end

local function T_register_expansion()
  lbt.api.reset_global_data()
  local pc = lbt.fn.parsed_content(good_input_6)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  EQ(l[1], [=[The quadratic formula is \[ \ensuremath{x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}}. \] \par]=])
  EQ(l[2], [[Viewers of Roy and HG's \emph{The Dream}\footnote{Hello Bolivia!} \dots \par]])
  EQ(l[3], [[No longer defined: ◊fn1 \par]])
  EQ(l[4], [[Never was defined: ◊abc \par]])
  EQ(l[5], [[◊abc and $\ensuremath{x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}}$ \par]])
end

local function T_simplemath()
  lbt.api.set_log_channels('allbuttrace')
  -- Gain backdoor access to the simplemath macro
  local t = lbt.fn.template_object_or_error('lbt.Math')
  local m = t.macros.simplemath
  local assert_math = function(input, expected)
    local actual = m(input)
    local expected = F([[\ensuremath{%s}]], expected)
    EQ(actual, expected)
  end
  assert_math([[sin2th = 0.32]], [[\sin^{2} \theta = 0.32]])
  assert_math([[cot32b]], [[\cot^{32} b]])
  assert_math([[cot32B]], [[\cot^{32} B]])
  assert_math([[a^2 + b^2 = c^2]], [[a^2 + b^2 = c^2]])
  assert_math([[forall n in \nat, n+1 > n]], [[\forall n \in \nat, n+1 > n]])
  -- assert_math([[\lim_{n to infty} 1/n = 0]], [[\lim_{n \to \infty} 1/n = 0]])
  -- ^^^ Doesn't work because infty is not a whole space-separated word.
  --     A stetch goal would be to parse out {...} first and make this work.
  assert_math([[x ge alpha]], [[x \ge \alpha]])
  assert_math([[alpha beta gamma]], [[\alpha \beta \gamma]])
  assert_math([[xxx]], [[xxx]])
  assert_math([[xxx]], [[xxx]])
  assert_math([[xxx]], [[xxx]])
  assert_math([[xxx]], [[xxx]])
end

-- local function EXP_sip()
--   local compile = pl.sip.compile
--   local text = [[forall n in \Real, n^2 > n \text{and} sin2th equiv 1 - cos2th]]
--   local p1 = compile('\\%a')
--   local res = {}
--   if p1(text,res) then
--     IX(res)
--   end
-- end

----------------------------------------------------------------------

-- flag:
--   0: don't run tests (but continue the program)
--   1: run tests and exit
--   2: run tests and continue
local function RUN_TESTS(flag)
  if flag == 0 then return end

  print("\n\n======================= <TESTS>")
  lbt.api.set_debug_mode(true)

  -- IX(lbt.system.template_register)

  -- T_pragmas_and_other_lines()
  -- T_parsed_content_1()
  -- T_extra_sources()
  -- T_add_template_directory()
  -- T_expand_Basic_template_1()
  -- T_expand_Basic_template_2()
  -- T_util()
  -- T_template_styles_specification()
  -- T_number_in_alphabet()
  -- T_style_string_to_map()
  -- T_style_resolver_1a()
  -- T_style_resolver_1b()
  -- T_styles_in_test_question_template_5a()
  -- T_styles_in_test_question_template_5b()
  -- T_register_expansion()
  -- T_simplemath()
  T_parse_commands_lpeg()
  -- EXP_sip()

  if flag == 1 then
    print("======================= </TESTS> (exiting)")
    os.exit()
  elseif flag == 2 then
    print("======================= </TESTS>")
  else
    error('Invalid flag for RUN_TESTS in lbt-7-test.lua')
  end
end

RUN_TESTS(1)
