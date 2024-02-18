
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

-- simplemath macro -- get rid of a lot of backslashes, and potentially more
--
-- Turn 'sin2x + cos2x equiv 1' into '\sin^2 x + \cos^2 x \equiv 1'
-- Turn 'costh = 0.72' into '\cos\theta = 0.72'

do
  local makeset = function (text)
    return pl.Set(lbt.util.space_split(text))
  end
  local makemap = function (text)
    local bits = lbt.util.space_split(text)
    local map  = pl.Map()
    for i = 1,#bits,2 do
      local key = bits[i]
      local val = bits[i+1]
      map[key] = val
    end
    return map
  end
  local trig = makeset'sin cos tan sec csc cot'
  local other = makeset[[equiv forall exists nexists implies to in notin mid nmid
                         quad le ge ne iff sqrt frac tfrac dfrac not neg
                         subset subseteq nsubseteq superset superseteq nsuperseteq
                         sum infty prod
                         ]]
  local alpha = makeset[[alpha beta gamma delta epsilon zeta eta theta iota
                         kappa lambda mu nu xi omicron pi rho sigma tau
                         upsilon phi chi psi omega
                         Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota
                         Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma Tau
                         Upsilon Phi Chi Psi Omega]]
  local abbrev = makemap[[al alpha be beta ga gamma de delta ep epsilon th theta la lambda
                          Al Alpha Be Beta Ga Gamma De Delta Ep Epsilon Th Theta La Lambda]]
  local process_abbrev = function (word)
    if abbrev[word] then
      return '\\'..abbrev[word]
    else
      return word
    end
  end

  local process_alpha = function (word)
    if alpha[word] then
      return '\\'..word
    else
      return word
    end
  end

  local process_trig = function (word)
    local res      = {}
    local pattern1 = '$a{stem}$d{index}$a{var}'
    local pattern2 = '$a{stem}$d{index}'
    local m        = pl.sip.match
    if m(pattern1, word, res) or m(pattern2, word, res) then
      -- we have matched something like cos2th or tan5x or just sin3
      -- but beware: it could be rubbish like abcde7def or xyz47 or sinvbg3u
      lbt.log('dev', 'Pattern match on %s was successful', word)
      lbt.log('dev', 'res: %s', lbt.pp(res))
      local stem, index, var = res.stem, res.index, res.var
      if trig[stem] and var then
        -- cos2th or tan5B
        return F([[\%s^{%s} %s]], stem, index, process_abbrev(var))
      elseif trig[stem] then
        -- sin3 or csc2
        return F([[\%s^{%s}]], stem, index)
      else
        return word
      end
    else
      -- it could just be 'sinx' or 'cosal' or something
      local stem = word:sub(1,3)
      local rest = word:sub(4)
      if trig[stem] then
        return F([[\%s %s]], stem, process_abbrev(rest))
      else
        return word
      end
    end
  end

  local process = function (word)
    lbt.log('dev', 'lbt.Math macro simplemath: %s', word)
    local result = nil
    if trig[word] or alpha[word] or other[word] then
      lbt.log('dev', 'process A')
      result = '\\'..word
    elseif #word > 3 and trig[word:sub(1,3)] then
      lbt.log('dev', 'process B')
      result = process_trig(word)
    else
      lbt.log('dev', 'process C')
      result = process_abbrev(word)
    end
    lbt.log('dev', '   ~> result: %s', result)
    return result
  end

  m.simplemath = function (text)
    local words = lbt.util.space_split(text)
    local tokens = pl.List()
    for word in words:iter() do
      local substitute = process(word)
      tokens:append(substitute)
    end
    return F([[\ensuremath{%s}]], tokens:concat(' '))
  end

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

