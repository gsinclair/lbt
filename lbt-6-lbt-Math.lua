
-- +---------------------------------------+
-- | lbt.Math                              |
-- |                                       |
-- | Macros for integrals and vectors      |
-- +---------------------------------------+

local F = string.format

local f = {}   -- functions
local a = {}   -- number of arguments
local s = {}   -- styles
local m = {}   -- macros

s.vector = { format = 'bold' }

--------------------------------------------------------------------------------

-- _vector_ is a flexible vector renderer. Here are examples of the arguments
-- it can handle. Arguments are space-separated. Remember they are text.
--
--   a                 use style 'vector.format' to choose (bold) | arrow | tilde
--
--   AB                italic overarrow
--
--   2 -5              column vector
--   1 6 -4
--   row 3 8 1         can force row
--   col 3 8 1         but column is the default
--
--  The macros vecbold, vecarrow and vectilde are provided to force a style
--  if needed.

local function vector_pronumeral(x)
  local format = lbt.util.get_style('vector.format')
  if format == 'bold' then
    return F([[\ensuremath{\mathbf{%s}}]], x)
  elseif format == 'arrow' then
    -- Use \vv from 'esvect' package
    return F([[\ensuremath{\vv{%s}}]], x)
  elseif format == 'tilde' then
    -- Use \underaccent from 'accents' package
    return F([[\ensuremath{\underaccent{\tilde}{%s}}]], x)
  else
    local errormsg1 = F('Invalid style value for vector.format: <%s>', format)
    local errormsg2 = 'Valid options: boldrm | boldit | arrow | tilde'
    return lbt.util.latex_macro_error(errormsg1 .. '\n' .. errormsg2)
  end
end

local function vector_segment(ab)
  return F([[\ensuremath{\vv{%s}}]], ab)
end

s.vector = { format = 'bold' }
m.vector = function (text)
  local args = lbt.util.space_split(text)
  local n = #args
  if n == 1 then
    -- It is either a pronumeral like 'p' or a segment like 'AB'.
    local arg = args[1]
    if arg:match('^%l$') or arg == '0' then
      return vector_pronumeral(arg)
    elseif arg:match('^%u%u$') then
      return vector_segment(arg)
    else
      return lbt.util.latex_macro_error('Invalid sole arg to vector macro: ' .. arg)
    end
  elseif n > 1 then
    -- It is a row or column vector.
    if args[1] == 'row' then
      args:remove(1)
      local contents = table.concat(args, ',')
      return F([[\ensuremath{\left( %s \right)}]], contents)
    elseif args[1] == 'col' then
      args:remove(1)
      local contents = table.concat(args, [[ \\ ]])
      return F([[\ensuremath{\begin{pmatrix} %s \end{pmatrix}}]], contents)
    else
      -- col is default
      local contents = table.concat(args, [[ \\ ]])
      return F([[\ensuremath{\begin{pmatrix} %s \end{pmatrix}}]], contents)
    end
  else
    return lbt.util.latex_macro_error('Math:vector -- at least one argument needed')
  end
end

-- Input: a pronumeral like 'a' or 'v' or the value zero '0'.
-- Output: that letter/zero rendered as a bold vector.
-- Comment: this allows author to force a desired style.
m.vecbold = function (x)
  return F([[\ensuremath{\mathbf{%s}}]], x)
end

-- Input: a pronumeral like 'a' or 'v' or the value zero '0'.
-- Output: that letter/zero rendered as a vector with arrow overhead.
-- Comment: this allows author to force a desired style.
m.vecarrow = function (x)
  return F([[\ensuremath{\vv{%s}}]], x)
end

-- Input: a pronumeral like 'a' or 'v' or the value zero '0'.
-- Output: that letter/zero rendered as a vector with tilde underneath.
-- Comment: this allows author to force a desired style.
m.vectilde = function (x)
  return F([[\ensuremath{\underaccent{\tilde}{%s}}]], x)
end

m.vectorijk = function (text)
  local force_sign = function (x)
    if x:startswith('+') or x:startswith('-') or x == '0' then
      return x
    else
      return '+'..x
    end
  end
  local terms = lbt.util.space_split(text):map(force_sign)
  if #terms < 2 or #terms > 3 then
    return lbt.util.latex_macro_error('expect 2-3 args to vectorijk' .. arg)
  else
    local i, j, k = m.vector('i'), m.vector('j'), m.vector('k')
    local unitvectors = {i,j,k}
    local result = pl.List()
    for i = 1,#terms do
      if terms[i] ~= '0' then
        local t = terms[i] .. unitvectors[i]
        result:append(t)
      end
    end
    return result:join(' ')
  end
end

--------------------------------------------------------------------------------

-- Integrals: definite and indefinite
--
-- Arguments are comma separated. Space is optional.
--
--   \Int{x^2 \sin x, dx}                     indefinite
--   \Int{0,1,x^2 sin x,dx}                   definite
--   \Int{ds,\tan\theta,d\theta}              indefinite, force displaystyle
--   \Int{ds,0,\pi/4,\tan\theta,d\theta}      definite, force displaystyle

m.integral = function (text)
  local args = lbt.util.comma_split(text)
  local displaystyle = false
  if args[1] == 'ds' then
    displaystyle = true
    args:remove(1)
  end
  local integral = nil
  if #args == 2 then
    -- Indefinite
    integral = F([[\int %s\,%s]], args[1], args[2])
  elseif #args == 4 then
    -- Definite
    integral = F([[\int_{%s}^{%s} %s\,%s]], args[1], args[2], args[3], args[4])
  else
    local emsg = 'Math:integral requires 2 or 4 args with optional ds.'
    lbt.log(1, emsg)
    lbt.log(1, 'The invalid argument to Math:integral was "%s"', text)
    return lbt.util.latex_macro_error(emsg)
  end
  if displaystyle then
    integral = F([[\displaystyle %s]], integral)
  end
  return F([[\ensuremath{%s}]], integral)
end

--------------------------------------------------------------------------------

return {
  name      = 'lbt.Math',
  desc      = 'Specific support for mathematical typesetting',
  sources   = {},
  init      = nil,
  expand    = nil,
  functions = f,
  arguments = a,
  styles    = s,
  macros    = m,
}

