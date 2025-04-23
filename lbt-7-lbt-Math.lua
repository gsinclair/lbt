
-- +---------------------------------------+
-- | lbt.Math                              |
-- |                                       |
-- | Macros for integrals and vectors      |
-- +---------------------------------------+

local F = string.format

local f = {}   -- functions
local a = {}   -- number of arguments
local op = {}  -- opargs
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

local function vector_pronumeral(x, format)
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
    local errormsg2 = 'Valid options: bold | arrow | tilde'
    -- NOTE: the options listed above was once boldrm | boldit | ...
    -- Should I implement those?
    return lbt.util.latex_macro_error(errormsg1 .. '\n' .. errormsg2)
  end
end

local function vector_segment(ab)
  return F([[\ensuremath{\vv{\mathit{%s}}}]], ab)
end

op.vector = { format = 'bold' }
m.vector = function (text, ctx)
  local args
  if text:find(',') then
    args = lbt.util.comma_split(text)
  else
    args = lbt.util.space_split(text)
  end
  local n = #args
  if n == 1 then
    -- It is either a pronumeral like 'p' or a segment like 'AB'.
    local arg = args[1]
    if arg:match('^%l$') or arg == '0' then
      local format = lbt.util.resolve_oparg_for_macro('vector.format', ctx)
      return vector_pronumeral(arg, format)
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
m.vecbold = function (x, _)
  return F([[\ensuremath{\mathbf{%s}}]], x)
end

-- Input: a pronumeral like 'a' or 'v' or the value zero '0'.
-- Output: that letter/zero rendered as a vector with arrow overhead.
-- Comment: this allows author to force a desired style.
m.vecarrow = function (x, _)
  return F([[\ensuremath{\vv{%s}}]], x)
end

-- Input: a pronumeral like 'a' or 'v' or the value zero '0'.
-- Output: that letter/zero rendered as a vector with tilde underneath.
-- Comment: this allows author to force a desired style.
m.vectilde = function (x, _)
  return F([[\ensuremath{\underaccent{\tilde}{%s}}]], x)
end

m.vectorijk = function (text, ctx)
  local force_sign = function (x)
    if x:startswith('+') or x:startswith('-') or x == '0' then
      return x
    else
      return '+'..x
    end
  end
  local normalise = function(i, term)
    if term == '1' then term = '' end
    if term == '-1' then term = '-' end
    if i > 1 then term = force_sign(term) end
    return term
  end
  local terms
  if text:find(',') then
    terms = lbt.util.comma_split(text)
  else
    terms = lbt.util.space_split(text)
  end
  if #terms < 2 or #terms > 3 then
    return lbt.util.latex_macro_error('expect 2-3 args to vectorijk')
  else
    local i, j, k = m.vector('i', ctx), m.vector('j', ctx), m.vector('k', ctx)
    local unitvectors = {i,j,k}
    local result = pl.List()
    for i = 1,#terms do
      terms[i] = normalise(i, terms[i])
      if terms[i] ~= '0' then
        local t = terms[i] .. [[{\kern 0.1em}]] .. unitvectors[i]
        result:append(t)
      end
    end
    return F([[\ensuremath{%s}]], result:join(' '))
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
-- Turn 'sin2 x + cos2 x equiv 1' into '\sin^2 x + \cos^2 x \equiv 1'
-- Turn 'cos th = 0.72' into '\cos \theta = 0.72'

local enable_simplemath_logging = false
local simplemathlog = nil
if enable_simplemath_logging then
  simplemathlog = function(text)
    lbt.log('simplemath', text)
  end
else
  simplemathlog = function(text)
  end
end

do
  local makeset = function (text)
    return pl.Set(lbt.util.space_split(text))
  end
  local makemap = function (text)
    local bits = lbt.util.space_split(text)
    local map  = {}
    for i = 1,#bits,2 do
      local key = bits[i]
      local val = bits[i+1]
      map[key] = val
    end
    return map
  end
  local trig = makeset'sin cos tan sec csc cot arcsin'
  local other = makeset[[equiv forall exists nexists implies to in notin mid nmid
                         quad le ge ne iff sqrt frac tfrac dfrac not approx sim
                         neg wedge vee
                         subset subseteq nsubseteq superset superseteq nsuperseteq
                         int sum infty prod lim
                         cdot times divide div
                         dots cdots ldots
                         log ln
                         pm
                         angle degree
                         binom
                         triangle
                         text
                         ]]
  local alpha = makeset[[alpha beta gamma delta epsilon zeta eta theta iota
                         kappa lambda mu nu xi omicron pi rho sigma tau
                         upsilon phi chi psi omega
                         Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota
                         Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma Tau
                         Upsilon Phi Chi Psi Omega]]
  local abbrev = makemap[[al alpha be beta ga gamma de delta ep epsilon th theta la lambda
                          Al Alpha Be Beta Ga Gamma De Delta Ep Epsilon Th Theta La Lambda]]

  local process_trig = function (fn, power)
    return F([[\%s^{%s}]], fn, power)
  end

  local mathit = function(letters)
    return F([[\mathit{%s}]], letters)
  end

  local process_word = function (word)
    simplemathlog('simplemath word: ' .. word)
    if alpha[word] or other[word] or trig[word] then
      return '\\'..word
    elseif abbrev[word] then
      return '\\'..abbrev[word]
    else
      return word
    end
  end

  local lpeg = require('lpeg')
  local P, C, Ct, V, loc = lpeg.P, lpeg.C, lpeg.Ct, lpeg.V, lpeg.locale()
  local backslash = P('\\')
  local tag = function(label)
    return function(x) simplemathlog('simplmath tag ' .. label .. ': <' .. x .. '>'); return x end
  end
  local smparse = P{ 'sm',
    command = C(backslash * (loc.alpha^1 + '!' + ',')) / tag('command'),
    trigf = P(false) + 'sin' + 'cos' + 'tan' + 'sec' + 'csc' + 'cot' +
                       'sinh' + 'cosh' + 'tanh',
    trig  = (C(V'trigf') * C(loc.digit^1)) / process_trig,
    upper = C(loc.upper^2) / mathit,
    word  = C(loc.alpha^1) / process_word,
    space = C(loc.space^1) / tag('space'),
    other = C( (1-(loc.alpha+loc.space+backslash))^1 ) / tag('other'),
    item  = V'command' + V'trig' + V'upper' + V'word' + V'space' + V'other',
    sm = Ct(V'item'^0) * -1
  }

  m.simplemath = function (text, _)
    simplemathlog('simplemath: ' .. text)
    local transformed = smparse:match(text)
    if transformed then
      return F([[\ensuremath{%s}]], table.concat(transformed, ''))
    else
      local errormsg = F('«Unable to parse simplemath text: \\Verb====%s====»', text)
      return F([[\textbf{\textcolor{red} %s }]], errormsg)
    end
  end

end

--------------------------------------------------------------------------------

-- mathlistand macro
--
-- Example invocation: \mathlistand{a,b,c,d}
-- Output: $a$, $b$, $c$ and $d$

m.mathlistand = function (text)
  local values = lbt.util.comma_split(text)
  local n = values:len()
  values:transform(function(x) return F('$%s$', pl.stringx.strip(x)) end)
  local last = values[n]
  local rest = values:remove(n)
  return rest:concat(', ') .. ' and ' .. last
end

--------------------------------------------------------------------------------

-- mathlistor macro
--
-- Example invocation: \mathlistor{a,b,c,d}
-- Output: $a$, $b$, $c$ or $d$

m.mathlistor = function (text)
  local values = lbt.util.comma_split(text)
  local n = values:len()
  values:transform(function(x) return F('$%s$', pl.stringx.strip(x)) end)
  local last = values[n]
  local rest = values:remove(n)
  return rest:concat(', ') .. ' or ' .. last
end

--------------------------------------------------------------------------------

-- mathlist macro
--
-- Example invocation: \mathlist{11,13,17,19}
-- Output: $11$,$13$,$17$,$19$
--
-- Note: no 'and' before final element

m.mathlist = function (text)
  local values = lbt.util.comma_split(text)
  values:transform(function(x) return F('$%s$', pl.stringx.strip(x)) end)
  return values:concat(', ')
end

-- TODO: document
m.mathlistdots = function (text)
  local values = lbt.util.comma_split(text)
  values:transform(function(x) return F('$%s$', pl.stringx.strip(x)) end)
  values:insert(#values-1, [[\dots]])
  return values:concat(', ')
end

--------------------------------------------------------------------------------

-- mathsum macro
--
-- Example invocation: \mathsum{a,b,c,d}
-- Output: $a+b+c+d+e$

m.mathsum = function (text)
  local values = lbt.util.comma_split(text)
  values:transform(pl.stringx.strip)
  return '\\ensuremath{' .. values:concat('+') .. '}'
end

-- NOTE: Idea -- just use mathsum but transform DOTS into \dots.
-- Thus gain flexibility over where the dots appear.
m.mathsumdots = function (text)
  local values = lbt.util.comma_split(text)
  values:transform(pl.stringx.strip)
  values:insert(#values, [[\dots]])
  return '\\ensuremath{' .. values:concat('+') .. '}'
end

--------------------------------------------------------------------------------

-- mathseq macros
--
-- Example invocations:
--    \mathseq{T,1,2,3,4,5}           -->     $T_1, T_2, T_3, T_4, T_5$
--    \mathseqsum{T,1,2,3,4,5}        -->     $T_1 + T_2 + T_3 + T_4 + T_5$
--    \mathseqproduct{T,1,2,3,4,5}    -->     $T_1 \, T_2 \, T_3 \, T_4 \, T_5$
--    \mathseqdots{p,1,2,3,n}         -->     $p_1, p_2, p_3, \dots, p_n$
--    \mathseqdotssum{p,1,2,3,n}      -->     $p_1 + p_2 + p_3 + \dots + p_n$
--    \mathseqdotsproduct{p,1,2,3,n}  -->     $p_1 p_2 p_3 \dots p_n$

local mathseqterms = function (text)
  local args = lbt.util.comma_split(text)
  args:transform(pl.stringx.strip)
  local n = args:len()
  local pronumeral = args[1]
  local terms = pl.List()
  for i = 2,n do
    local term = F('%s_%s', pronumeral, args[i])
    terms:append(term)
  end
  return terms
end

local mathseqdotsterms = function (text)
  local terms = mathseqterms(text)
  terms:insert(#terms-1, '\\dots')
  return terms
end

m.mathseq = function (text)
  local terms = mathseqterms(text)
  return '\\ensuremath{' .. terms:concat(', ') .. '}'
end

m.mathseqsum = function (text)
  local terms = mathseqterms(text)
  return '\\ensuremath{' .. terms:concat(' + ') .. '}'
end

m.mathseqproduct = function (text)
  local terms = mathseqdotsterms(text)
  return '\\ensuremath{' .. terms:concat(' \\, ') .. '}'
end

m.mathseqdots = function (text)
  local terms = mathseqdotsterms(text)
  return '\\ensuremath{' .. terms:concat(', ') .. '}'
end

m.mathseqdotssum = function (text)
  local terms = mathseqdotsterms(text)
  return '\\ensuremath{' .. terms:concat(' + ') .. '}'
end

m.mathseqdotsproduct = function (text)
  local terms = mathseqdotsterms(text)
  return '\\ensuremath{' .. terms:concat(' \\, ') .. '}'
end

--------------------------------------------------------------------------------

-- primefactorisation macro
--
-- Example invocation: \primefactorisation{2,2,2,5,7,7,19}
-- Output: $2^3 \cdot 5 \cdot 7^2 \cdot 19$
--
-- Example invocation: \primefactorisation{explicit 2,2,2,5,7,7,19}
-- Output: $2^3 \cdot 5^1 \cdot 7^2 \cdot 19^1$

m.primefactorisation = function (text)
  local explicit = false
  if text:startswith('explicit ') then
    explicit = true
    text = text:sub(10)
  end
  local values = lbt.util.comma_split(text)
  values:transform(pl.stringx.strip)
  local tally = pl.OrderedMap()
  for x in values:iter() do
    if tally[x] then
      tally[x] = tally[x] + 1
    else
      tally[x] = 1
    end
  end
  local body = pl.List()
  for p, n in tally:iter() do
    if n == 1 and not explicit then
      body:append(p)
    else
      body:append(F('%s^%s', p, n))
    end
  end
  return '\\ensuremath{' .. body:concat(' \\cdot ') .. '}'
end

--------------------------------------------------------------------------------

return {
  name      = 'lbt.Math',
  desc      = 'Specific support for mathematical typesetting',
  sources   = {},
  init      = nil,
  expand    = nil,
  functions = f,
  posargs = a,
  opargs = op,
  macros    = m,
}

