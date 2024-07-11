--
-- We act on the global table `lbt` and populate its subtable `lbt.util`.
--
-- NOTE this is very much in progress.
--
-- The main intention of lbt.util.* is to be useful to people writing template
-- code. Given that, it arguably should have a better name.

local F = string.format

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
--  * tr:          token resolver (passed to the `expand` function)
--  * sr:          style resolver (passed to the `expand` function)
-- 
-- TODO update to use ocr and ol.
--
lbt.util.latex_expand_content_list = function (key, pc, ocr, ol)
  local list = pc:list_or_nil(key)
  if list == nil then
    lbt.log(2, "Asked to expand content list '%s' but it is not included in the content", key)
    -- TODO ^^^ add contextual information
    return ''
  end
  lines = lbt.fn.latex_for_commands(list, ocr, ol)
  return lines:concat('\n')
end

-- This is designed for use only in macro expansion, and only rarely.
-- Commands should use the resolver passed to them.
--
-- TODO: remove this
--
lbt.util.get_style = function (key)
  local sr = lbt.const.style_resolver
  if sr == nil then
    lbt.err.E001_internal_logic_error('lbt.const.style_resolver not available')
  end
  return sr(key)
end

-- This is designed for use only in macro expansion, and only rarely.
-- Commands should use the option lookup passed to them.
lbt.util.get_option_for_macro = function (key)
  local ol = lbt.const.option_lookup
  if ol == nil then
    lbt.err.E001_internal_logic_error('lbt.const.option_lookup not available')
  end
  local value = ol:_lookup(key)
  if value == nil then
    print(ol)
    lbt.err.E193_option_lookup_for_macro_failed(key, ol)
  end
  return value
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

lbt.util.combine_latex_fragments = function (...)
  return table.concat({...}, '\n\n')
end

function lbt.util.wrap_braces(x)
  return '{' .. x .. '}'
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


