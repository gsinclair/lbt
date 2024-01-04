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
  assert_string(1, str)
  for line in str:lines() do
    tex.print(line)
  end
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


