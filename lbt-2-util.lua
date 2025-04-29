--
-- We act on the global table `lbt` and populate its subtable `lbt.util`.
--
-- NOTE this is very much in progress.
--
-- The main intention of lbt.util.* is to be useful to people writing template
-- code. Given that, it arguably should have a better name.

local F = string.format

local impl = {}   -- namespace for helper functions

-- `tex.print` but with formatting. Hint: local-alias this to `P`.
function lbt.util.tex_print_formatted(text, ...)
  tex.print(string.format(text, ...))
end

-- Print each line in `str` with a separate call to `tex.print`.
function lbt.util.print_tex_lines(str)
  lbt.assert_string(1, str)
  for line in str:lines() do
    tex.print(line)
  end
end

-- Call this function from within a template `expand` function, perhaps even
-- multiple times. Most commonly it would be once and the key would be 'BODY'.
-- Arguments:
--  * key:         the name of the content section (e.g. BODY, INTRO, OUTRO)
--  * pc:          parsed content (passed to the `expand` function)
--
lbt.util.latex_expand_content_list = function (key, pc)
  local list = pc:list_or_nil(key)
  if list == nil then
    lbt.log(2, "Asked to expand content list '%s' but it is not included in the content", key)
    -- TODO ^^^ add contextual information
    return ''
  end
  local lines = lbt.fn.latex_for_commands(list)
  return lines:concat('\n')
end

-- This is designed for use in template functions `init` and `expand`.
--   The key needs to be qualified (e.g. vector.format, not just format); an error will
-- result otherwise.
lbt.util.resolve_oparg = function (qkey, ctx)
  lbt.assert_string(1, qkey)
  local ctx = lbt.fn.get_current_expansion_context()
  local found, value = ctx:resolve_oparg(qkey)
  if found == false then
    lbt.err.E192_oparg_lookup_failed(qkey)
  end
  return value
end

-- This is designed for use only in macro expansion. Commands have access to the
-- current expansion context and don't need to call 'util'.
--   The key needs to be qualified (e.g. vector.format, not just format); an error will
-- result otherwise.
lbt.util.resolve_oparg_for_macro = function (qkey, ctx)
  lbt.assert_string(1, qkey)
  assert(ctx ~= nil)
  assert(ctx.type == 'ExpansionContext')
  local found, value = ctx:resolve_oparg(qkey)
  if found == false then
    lbt.err.E193_oparg_lookup_for_macro_failed(qkey)
  end
  return value
end

lbt.util.lbt_commands_text_into_latex = function (text)
  local x = lbt.parser.parse_commands(text)
  if not x.ok then
    lbt.err.E002_general('(util.lbt_commands_text_into_latex) could not parse commands:\n'..text)
  end
  return lbt.fn.latex_for_commands(x.commands):join('\n\n')
end

-- `x` may be a string or a table.
-- To 'normalise' the output for these purposes, we want:
--  * a single string
--  * with no whitespace at the beginning of each line
--
-- The second requirement could be contentious in some circumstances, like
-- verbatim printing or code listings. We can revisit it later. Hopefully it
-- is not necessary. But I am having trouble getting accurate output at the
-- moment and need to make things as tight as possible.
lbt.util.normalise_latex_output = function (x)
  if type(x) == 'table' then
    x = x:concat('\n')
  elseif type(x) == 'string' then
    -- noop
  else
    lbt.err.E419_invalid_argument_normalise_latex(x)
  end
  local y = {[[\begingroup]], x, [[\endgroup]]}
  y = table.concat(y, '\n')
  y = y:gsub('\n +', '\n')
  return y
end

lbt.util.content_meta_or_nil = function (pc, key)
  local meta = pc:meta()
  return meta[key]
end

lbt.util.content_meta_or_error = function (pc, key)
  lbt.assert_string(2, key)
  local value = lbt.util.content_meta_or_nil(pc, key)
  if value == nil then
    lbt.err.E998_content_meta_value_missing(key)
    -- TODO ^^^ consider using lbt.util.template_error_quit instead,
    -- to better convey the idea that the error occurred inside expansion
    -- code.
  end
  return value
end

lbt.util.content_dictionary_or_nil = function (pc, key)
  return pc:dict_or_nil(key)
end

lbt.util.content_dictionary_or_error = function (pc, key)
  local dict = lbt.util.content_dictionary_or_nil(pc, key)
  if dict == nil then
    -- lbt.err.E997_content_dictionary_missing(key)
    -- TODO ^^^ consider using lbt.util.template_error_quit instead,
    -- to better convey the idea that the error occurred inside expansion
    -- code.
    --
    -- Acting on that TODO below:
    lbt.util.template_error_quit('Content dictionary has no value for key: %s', key)
  end
  return dict
end

-- Input: 'My name is !NAME! and I am !ADJ! to meet you',
--        { NAME = 'Jon', ADJ = 'pleased', AGE = 37 }
-- Output: 'My name is Jon and I am pleased to meet you'
-- Note: valid substitution tokens use upper-case, numbers, and underscores.
--       (But mostly just upper case.)
lbt.util.string_template_expand1 = function (template, values)
  local substitute = function(s)
    return values[s] or error("Can't perform template substitution on string: " .. s)
  end
  return template:gsub('!(%u[%u%d_]+)!', substitute)
end

-- Like string_template_expand1 but you can provide as many 'templates' as you like.
-- The output will concatenate
-- Example:
--   string_template_expand {
--     'My name is !NAME!.',
--     'I am !ADJ! to meet you,',
--     'and we will leave work at !TIME!.'
--     values = { NAME = 'Allie', ADJ = 'miffed', TIME = '17:30'}
--   }
-- Output:
--   My name is Allie.
--   I am miffed to meet you,
--   and we will leave work at 17:30.
lbt.util.string_template_expand = function (t)
  local lines = pl.List()
  for _, x in ipairs(t) do
    local transformed_line = lbt.util.string_template_expand1(x, t.values)
    lines:append(transformed_line)
  end
  return lines:concat('\n')
end

lbt.util.combine_latex_fragments = function (...)
  return table.concat({...}, '\n\n')
end

lbt.util.join_lines = function (...)
  return table.concat({...}, '\n')
end

function lbt.util.wrap_braces(x)
  return '{' .. x .. '}'
end

function lbt.util.wrap_brackets(x)
  return '[' .. x .. ']'
end

function lbt.util.wrap_parens(x)
  return '(' .. x .. ')'
end

-- Examples:
--   Positional arguments
--     wrap_environment { 'The rain in spain', 'center' }
--   Keyword arguments
--     wrap_environment { content = 'The rain in spain', environment = 'center' }
--   A single argument to the environment
--     wrap_environment { '...', 'array', arg = 'ccc' }
--   Multiple arguments to the environment
--     wrap_environment { '...', 'tabularx', args = { '\textwidth', '|l|c|r|' } }
--   An optional argument to the environment
--     wrap_environment { '...', 'enumerate', oparg = 'label=\roman*.' }
--   Mandatory _and_ optional arguments
--     wrap_environment { '...', 'multicols', arg = '2', oparg = '\section{The user interface}' }
--   Mandatory and _two_ optional arguments
--     wrap_environment { '...', 'multicols', arg = '2', opargs = { '\section{The user interface}', '6cm' } }
--   Parenthetical argument to the environment
--     wrap_environment { '\psline(0,0)(5,5)', 'pspicture', parenarg = '(6,8)' }
--
-- Note:
--   All examples of environments I can find have the [] arg(s) _after_ the {} arg(s),
--   so that is what we will do. If a counterexample comes up, I will provide a 'rawargs'
--   option like { '...', env, rawargs = '[4]{hello}[x]' }
function lbt.util.wrap_environment(kwargs)
  local k = kwargs
  local braceargs = function()
    local x = k.args or { k.arg }
    return #x > 0 and pl.List(x):map(lbt.util.wrap_braces):concat() or ''
  end
  local bracketargs = function()
    local x = k.opargs or { k.oparg }
    return #x > 0 and pl.List(x):map(lbt.util.wrap_brackets):concat() or ''
  end
  local parenargs = function()
    local x = k.parenargs or { k.parenarg }
    return #x > 0 and pl.List(x):map(lbt.util.wrap_parens):concat() or ''
  end
  local t = pl.List()
  t:append [[\begin{!ENV!}!BRACE_ARGS!!BRACKET_ARGS!!PAREN_ARGS!]]
  t:append '!CONTENT!'
  t:append [[\end{!ENV!}]]
  t.values = {
    ENV          = kwargs[2] or kwargs.environment or error('lbt.util.wrap_environment called incorrectly - no environment'),
    CONTENT      = kwargs[1] or kwargs.content     or error('lbt.util.wrap_environment called incorrectly - content nil?'),
    BRACE_ARGS   = braceargs(),
    BRACKET_ARGS = bracketargs(),
    PAREN_ARGS   = parenargs(),
  }
  return lbt.util.string_template_expand(t)
end

-- x: latex content
-- o: an options resolver; we are interested only in o.leftindent
-- If leftindent is a value like '3em', wrap x in an adjustwidth environment
-- to set the left margin.
function lbt.util.leftindent(x, o)
  if o.leftindent == nil or o.leftindent == 'nil' then
    return x
  else
    return lbt.util.wrap_environment { x, 'adjustwidth', args = { o.leftindent, '' } }
  end
end

-- x: latex content
-- o: an options resolver; we are interested in o.leftindent and o.centre and o.center
-- If leftindent is a value like '3em', wrap x in an adjustwidth environment
-- to set the left margin.
-- If centre or center is true, wrap x in a 'center' environment.
-- TODO: decide whether to implement 'indent' as well as 'leftindent', for example.
-- TODO: change this to apply_general_formatting and support nopar and fontsize, and take a list of formats to apply
function lbt.util.apply_horizontal_formatting(x, o)
  if o.center or o.centre then
    return lbt.util.wrap_environment { x, 'center' }
  elseif o.leftindent then
    return lbt.util.wrap_environment { x, 'adjustwidth', args = { o.leftindent, '' } }
  else
    return x
  end
end

-- x: latex content
-- o: an options resolver; we are interested in o.fontsize
-- Applies environment 'small' or 'footnotesize' or ...
function lbt.util.apply_style_formatting(x, o)
  if o.fontsize then
    return lbt.util.wrap_environment { x, o.fontsize }
  else
    return x
  end
end

-- TODO: make it do we don't have to check o.spreadlines etc here; do it earlier
local formatting_handlers = {
  spreadlines = function(x, o)
    if o.spreadlines then
      return lbt.util.wrap_environment { x, 'spreadlines', arg = o.spreadlines }
    else
      return x
    end
  end,

  par = function(x, o)
    if o.par then
      return x .. [[ \par]]
    else
      return x
    end
  end
}

-- XXX: remove me
--
-- function lbt.util.handle_nopar(x, o)
--   if o.nopar then return x
--   else return x .. [[ \par ]]
--   end
-- end

-- general_formatting_wrap(x, o, 'leftalign center par')
--   x: latex content to be processed
--   o: option resolver
--   keys: list (or space-separated string) of formatting keys that are to be applied
function lbt.util.general_formatting_wrap(x, o, keys)
  -- 1. Sort out the 'keys' value.
  if type(keys) == 'string' then
    keys = lbt.util.space_split(keys)
  elseif type(keys) == 'table' then
    -- good
  else
    -- TODO: more specific error code
    lbt.err.E001_internal_logic_error('Invalid *keys* value: ' .. keys)
  end
  -- 2. Apply each formatting key in turn. 'nopar' is special.
  for option in keys:iter() do
    local handler = formatting_handlers[option]
    if handler == nil then
      -- TODO: more specific error code
      lbt.err.E001_internal_logic_error('Invalid formatting key: ' .. option)
    end
    if o[option] then
      x = handler(x,o)
    else
      -- no need to do anything
    end
  end
  return x
end

-- Input: '4..17'    Output: 4, 17
-- Invalid input causes fatal error.
function lbt.util.parse_range(text)
  return lbt.parser.parse_range(text)
end

-- Input: '2 5 6..8 19 25..28'    Output: { 2,5,6,7,8,19,25,26,27,28 }
-- Invalid input causes fatal error.
function lbt.util.parse_numbers_and_ranges(text)
  local bits = lbt.util.space_split(text)
  local result = pl.List()
  for x in bits:iter() do
    local a, b = lbt.util.parse_range(x)
    for n = a,b do
      result:append(n)
    end
  end
  return result
end

-- Input: '2023-07-22'    Output: a pl.Date object
-- Invalid input causes fatal error.
function lbt.util.parse_date(text)
  local df = pl.Date.Format 'yyyy-mm-dd'
  return df:parse(text)
end

-- Given arguments to a token, see if the first one is an "options" argument.
-- Return the options argument (or nil) and the rest of the arguments.
-- e.g.
--   [a=5,b=7], X, Y, Z     -->  a=5,b=7   followed by   { X, Y, Z }
--   W, X, Y, Z             -->  nil       followed by   { W, X, Y, Z }
-- What signifies an options argument? It is surrounded by [].
--
-- Input: args (List)
--
-- TODO Allow caller to specify which index to look at for the options.
--      We currently only look at the first, but I think sometimes it
--      would be useful to look at the second.
-- XXX: Remove this code. Should be using normal option parsing!
function lbt.util.extract_option_argument (args)
  if args:len() == 0 then
    return nil, pl.List()
  else
    local first = args[1]
    if first:startswith('[') and first:endswith(']') then
      return first:sub(2,-2), args:slice(2,-1)
    else
      return nil, args
    end
  end
end

-- Input:   cols=3, vspace=2pt
-- Output:  { cols = '3', vspace = 2pt }
-- XXX: Remove this code. Should be using normal option parsing!
function lbt.util.parse_options(text)
  local result = pl.Map()
  local bits   = lbt.util.comma_split(text)
  for x in bits:iter() do
    local t = {}
    if pl.sip.match('$v{key} = $S{value}', x, t) then
      result[t.key] = t.value
    else
      return nil
    end
  end
  return result
end

-- double_colon_split('a :: b :: c')    -> {a,b,c}
function lbt.util.double_colon_split(text)
  local result = pl.utils.split(text, '%s+::%s+')
  return pl.List(result)
end

-- space_split('a b c d')      -> {a,b,c,d}
-- space_split('a b c d', 2)   -> {a,b c d}
function lbt.util.space_split(text, n)
  local result = nil
  if n == nil then
    result = pl.utils.split(text, '%s+')
  else
    result = pl.utils.split(text, '%s+', false, n)
  end
  return pl.List(result)
end

-- Split on comma and remove any space.
-- comma_split('one,two   ,     three') --> {one,two,three}
function lbt.util.comma_split(text)
  local result = pl.utils.split(text, '%s*,%s*')
  return pl.List(result)
end

-- newline_split('a \n b \n c')    -> { 'a ', 'b ', 'c' }
function lbt.util.newline_split(text)
  local result = pl.utils.split(text, '\n')
  return pl.List(result)
end

-- simply calls penlight's string:split but returns a List instead of a plain table
function lbt.util.split(text, sep)
  local result = pl.utils.split(text, sep)
  return pl.List(result)
end

-- Input: four arguments 'Cats' '* Black' '* White' 'Dogs' '* Large' '* * Bloodhound' '* * Labrador'
-- Output, with grouped == nil:
--   {0, Cats} {1, Black} {1, White} {0, Dogs} {1, Large} {2, Bloodhound} {2, Labrador}
-- Output, with grouped == 'grouped':
--   {0, {Cats}} {1, {Black, White}} {0, {Dogs}} {1, {Large}} {2, {Bloodhound, Labrador}}
function lbt.util.analyse_indented_items(args, grouped)
  if grouped == nil then
    return args:map(impl.analyse_item)
  elseif grouped == 'grouped' then
    local items = lbt.util.analyse_indented_items(args, nil)
    return impl.grouped_items(items)
  else
    error('lbt.util.analyse_indented_items: second argument must be nil or "grouped"')
  end
end

impl.analyse_item = function(text)
  return lbt.parser.parse_list_item(text)
end

-- Input:   {0, Cats} {1, Black} {1, White} {0, Dogs} {1, Large} {2, Bloodhound} {2, Labrador}
-- Output:  {0, {Cats}} {1, {Black, White}} {0, {Dogs}} {1, {Large}} {2, {Bloodhound, Labrador}}
impl.grouped_items = function(items)
  local err = function () error('unable to group items for list') end
  local mkentry = function(l,t) return { l, pl.List{t} } end
  local addtext = function(e,t) e[2]:append(t) end
  ;   if items:len() == 0 then err() end
  local result = pl.List()
  -- E is the 'current entry' and L is the 'current level'
  local L, E, text, level
  L, text = table.unpack(items[1])
  ;   if L ~= 0 then err() end
  E = mkentry(L, text)
  result:append(E)
  for i = 2,items:len() do
    level, text = table.unpack(items[i])
    if level == L then
      addtext(E, text)
    elseif level == L + 1 then
      L = level
      E = mkentry(L, text)
      result:append(E)
    elseif level > L + 1 then
      err()
    else
      L = level
      E = mkentry(L, text)
      result:append(E)
    end
  end
  return result
end

-- Replace curly quotes (single or double) with straight quotes.
function lbt.util.straighten_quotes(text)
  local x = text
  -- if x:find('\226') then DEBUGGER() end
  x = x:gsub('\226\128\156', '\034')
  x = x:gsub('\226\128\157', '\034')
  -- x = text:gsub('[‘’]', '\'')
  return x
end

function lbt.util.table_keys_string(t)
  local m = pl.Map(t)
  return m:keys():join(',')
end

-- When expanding an LBT macro like lbt.Math.myvec, an error might occur.
-- This function helps you format a red flag for the Latex output.
function lbt.util.latex_macro_error(errormsg)
  local emsg1 = F('LBT Latex macro error occurred: %s', errormsg)
  local emsg2 = F([[\textrm{\color{lbtError}\bfseries %s}]], emsg1)
  lbt.log(1, emsg1)
  return emsg2
end

function lbt.util.template_error_quit(errormsg, ...)
  local emsg1 = 'Error occurred while expanding template: \n  '
  local emsg2 = F(errormsg, ...)
  lbt.err.quit_with_error(emsg1 .. emsg2)
end

--------------------------------------------------------------------------------

-- Roman numerals code, slightly adapted from
--     https://gist.github.com/efrederickson/4080372
--     efrederickson/RomanNumeralConverter.lua
--     Copyright (C) 2012 LoDC

local numbers = { 1, 5, 10, 50, 100, 500, 1000 }
local chars = { "i", "v", "x", "l", "c", "d", "m" }

local function to_roman_numerals(s)
  s = tonumber(s)
  if not s or s ~= s then error"Unable to convert to number" end
  if s == math.huge then error"Unable to convert infinity" end
  s = math.floor(s)
  if s <= 0 then return s end
  local ret = ""
  for i = #numbers, 1, -1 do
    local num = numbers[i]
    while s - num >= 0 and s > 0 do
      ret = ret .. chars[i]
      s = s - num
    end
    for j = 1, i - 1 do
      local n2 = numbers[j]
      if s - (num - n2) >= 0 and s < num and s > 0 and num - n2 ~= n2 then
        ret = ret .. chars[j] .. chars[i]
        s = s - (num - n2)
        break
      end
    end
  end
  return ret
end

-- Got a number and need a character representation like a,b,c,...
-- Or a roman numeral?
-- Latex has macros for these, to use with counters, but we are in Lua.
--
-- n:      the number
-- alph:   latin | Latin | roman | Roman
function lbt.util.number_in_alphabet(n, alph)
  if alph == 'latin' then
    if n < 1 or n > 26 then lbt.err.E401_cant_convert_to_latin(n) end
    local x = 'abcdefghijklmnopqrstuvwxyz'
    return x:at(n)
  elseif alph == 'Latin' then
    return string.upper(lbt.util.number_in_alphabet(n, 'latin'))
  elseif alph == 'roman' then
    if n < 1 or n > 1000000 then lbt.err.E401_cant_convert_to_roman(n) end
    return to_roman_numerals(n)
  elseif alph == 'Roman' then
    return string.upper(lbt.util.number_in_alphabet(n, 'roman'))
  else
    lbt.err.E402_invalid_alphabet(alph)
  end
end
