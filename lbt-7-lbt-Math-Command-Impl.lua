
-- +---------------------------------------+
-- | MathCommandImpl                       |
-- |                                       |
-- | Implement the MATH command            |
-- +---------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand
local f = {}
local a = {}
local op = {}

local impl = {}

------------- abcde ---------------------------------------------

local MATH_SPECS = pl.Map {

  equation = {
    type = 'outer',
    env = 'equation',
    apply_label = true,
    selective_numbering = true
  },

  multiline = {        -- alias for 'multline'
    type = 'outer',
    env = 'multline',
    apply_label = true,
    selective_numbering = false
  },

  multline = {
    type = 'outer',
    env = 'multline',
    apply_label = true,
    selective_numbering = false
  },

  align = {
    type = 'outer',
    env = 'align',
    apply_label = false,
    selective_numbering = true
  },

  alignat = {
    type = 'outer',
    env = 'alignat',
    apply_label = false,
    selective_numbering = true,
    environment_argument = 'ncols'
  },

  flalign = {
    type = 'outer',
    env = 'flalign',
    apply_label = false,
    selective_numbering = true
  },

  gather = {
    type = 'outer',
    env = 'gather',
    apply_label = false,
    selective_numbering = true
  },

  eqsplit = {
    name = 'eqsplit',
    type = 'composite',
    env = 'split',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false
  },

  eqaligned = {
    name = 'eqaligned',
    type = 'composite',
    env = 'aligned',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false
  },

  eqalignedat = {
    name = 'eqalignedat',
    type = 'composite',
    env = 'alignedat',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false,
    environment_argument = 'ncols'
  },

  eqgathered = {
    name = 'eqgathered',
    type = 'composite',
    env = 'gathered',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false
  },

  eqlgathered = {
    name = 'eqlgathered',
    type = 'composite',
    env = 'lgathered',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false
  },

  eqrgathered = {
    name = 'eqrgathered',
    type = 'composite',
    env = 'rgathered',
    outer_env = 'equation',
    apply_label = true,
    selective_numbering = false
  },

  split = {
    type = 'inner',
    env = 'split',
    apply_label = false,
  },

  gathered = {
    type = 'inner',
    env = 'gathered',
    apply_label = false,
  },

  multilined = {       -- mathtools
    type = 'inner',
    env = 'multilined',
    apply_label = false,
  },

  aligned = {
    type = 'inner',
    env = 'aligned',
    apply_label = false,
  },

  alignedat = {
    type = 'inner',
    env = 'alignedat',
    apply_label = false,
  },

  lgathered = {        -- mathtools
    type = 'inner',
    env = 'lgathered',
    apply_label = false,
  },

  rgathered = {        -- mathtools
    type = 'inner',
    env = 'rgathered',
    apply_label = false,
  },

  leftsplit = {        -- my addition
    type = 'composite',
    name = 'leftsplit',
    env = 'split',
    outer_env = 'flalign',
    apply_label = true,
    selective_numbering = false,
    append_after_inner_env = '&&',
    leftalign = true
  },

  leftalign = {        -- my addition
    type = 'composite',
    name = 'leftalign',
    env = 'aligned',
    outer_env = 'flalign',
    apply_label = false,
    selective_numbering = true,
    append_after_inner_env = '&&',
    leftalign = true
  },

  leftalignat = {        -- my addition
    type = 'composite',
    name = 'leftalignat',
    env = 'alignedat',
    outer_env = 'flalign',
    environment_argument = 'ncols',
    apply_label = false,
    selective_numbering = true,
    append_after_inner_env = '&&',
    leftalign = true
  },

  continuation = {
    type = 'special',    -- my addition, not related to amstools or mathtools
    name = 'continuation'
  },

  commentary = {
    type = 'special',    -- my addition, not related to amstools or mathtools
    name = 'commentary'
  },

}


------------- Commands ------------------------------------------

local Opargs = {
  env = 'nil',
  -- display environments
  equation = false, gather = false, align = false, multiline = false,
  multline = false, alignat = false, flalign = false,
  -- inner environments
  gathered = false, split = false, aligned = false, alignedat = false,
  multilined = false, lgathered = false, rgathered = false,
  -- composite environments
  eqsplit = false, eqgathered = false, eqaligned = false, eqalignedat = false,
  eqlgathered = false, eqrgathered = false,
  -- virtual environments
  leftsplit = false, leftalign = false, leftalignat = false,
  -- additional pseudo-environments
  continuation = false, commentary = false,
  -- numbering and labeling
  eqnum = true, starred = false, noeqnum = false, label = 'nil',
  -- simplemath
  sm = true,
  -- arguments to environments
  ncols = 'nil',
  -- appearance
  linespace = 'nil', par = true, leftmargin = '2em',
  -- debugging
  debugmath = false,
}
local MATH = function(_, args, o, kw)
  -- NOTE: Having 'noeqnum' as an oparg is undesirable. LBT should be detecting
  -- opargs of the form noX, where X is a valid oparg, and setting X = false.
  -- (In fact, LBT used to do this, but I lost that feature during the great
  -- rewrite of 2025.)
  if o.starred or o.noeqnum then o:_set_local('eqnum', false) end
  local spec = impl.math_spec(o)
  local result
  if spec and spec.type == 'special' then
    result = impl.math_impl_special(spec, args, o, kw)
  elseif spec then
    result = impl.math_impl(spec, args, o, kw)
  else
    result = [[\lbtWarning{MATH command -- couldn't determine environment}]]
  end
  --
  if o.debugmath then
    lbt.debuglog('')
    lbt.debuglog('MATH output')
    lbt.debuglog(result)
  end
  --
  return result
end

------------- Implementation ------------------------------------

function impl.math_spec(o)
  local chosen_environment = 'equation'  -- default
  if o.env then
    chosen_environment = o.env
  else
    for key in MATH_SPECS:keys():iter() do
      if o[key] then
        chosen_environment = key
      end
    end
  end
  return MATH_SPECS[chosen_environment]
end

--------------------------------------------------------------------------------

function impl.math_impl(spec, args, o, kw)
  local lines, body, result
  -- The args are lines of mathematics. (Some might be \intertext{...}.)
  -- Apply simplemath to them, and whatever 'notag' commands are required to
  -- get the numbering right.
  lines = impl.apply_simplemath_or_intertext(args, o)
  lines = impl.apply_notag(lines, spec, o)
  lines = impl.apply_line_endings(lines, o)
  body = lines:concat('\n')
  -- The main work is done here, based on whether the chosen environment is
  -- inner, outer, or composite.
  if spec.type == 'inner' then
    result = impl.inner_environment_expansion(spec, body, o, kw)
  elseif spec.type == 'outer' then
    result = impl.outer_environment_expansion(spec, body, o, kw)
  elseif spec.type == 'composite' then
    result = impl.composite_environment_expansion(spec, body, o, kw)
  else
    return F([[\lbtWarning{not implemented yet: %s}]], spec.name or spec.env)
  end
  -- Apply final formatting touches.
  -- If it's a left-aligned equation, we probably want to adjust the margin.
  result = impl.apply_margin_adjustment(result, spec, o)
  -- And we're done.
  return result
end

-- Inner environment has a very simple Implementation.
function impl.inner_environment_expansion(spec, body, o, _)
  return impl.wrap_environment(body, spec.env, spec, o)
end

-- Outer environment needs to determine whether to use starred environment.
function impl.outer_environment_expansion(spec, body, o, kw)
  local environment = impl.environment_plain_or_starred(spec, spec.env, o, kw)
  return impl.wrap_environment(body, environment, spec, o)
end

-- Composite environment does a simple inner and a possibly starred outer.
function impl.composite_environment_expansion(spec, body, o, kw)
  body = impl.inner_environment_expansion(spec, body, o, kw)
  body = impl.apply_label_to_body(body, spec, o)
  body = impl.append_text_to_body(body, spec)
  local environment = impl.environment_plain_or_starred(spec, spec.outer_env, o, kw)
  return lbt.util.wrap_environment { body, environment }
end

-- We provide a layer above lbt.util.wrap_environment so that we can handle cases
-- like appending && to the inner environment.
function impl.wrap_environment(body, environment, spec, o)
  if spec.environment_argument then
    local key = spec.environment_argument
    local value = o[key]
    if value == nil then
      lbt.util.template_error_quit("oparg '%s' required for MATH environment '%s'", key, spec.name or spec.env)
    end
    return lbt.util.wrap_environment { body, environment, arg = value }
  else
    return lbt.util.wrap_environment { body, environment }
  end
end
--------------------------------------------------------------------------------

function impl.apply_simplemath_or_intertext(lines, o)
  local simplemathfunction = lbt.util.simplemath_with_current_context()
  local result = pl.List()
  for x in lines:iter() do
    local y = impl.process_text_line(x)
    if y then
      result:append(y)
    elseif o.sm then
      result:append(simplemathfunction(x))
    else
      result:append(x)
    end
  end
  return result
end

function impl.process_text_line(line)
  if impl.is_text_line(line) then
    return line
  elseif line:startswith('TEXT') or line:startswith('INTERTEXT') then
    return F('\\intertext{%s}', line:gsub('^[^%s]+%s*', ''))
  elseif line:startswith('STEXT') or line:startswith('SHORTTEXT') or line:startswith('SHORTINTERTEXT') then
    return F('\\shortintertext{%s}', line:gsub('^[^%s]+%s*', ''))
  else
    return nil
  end
end

-- A chance to add \notag to some lines to suppress numbering.
function impl.apply_notag(lines, spec, o)
  if not spec.selective_numbering then
    -- This environment does not allow for selective numbering.
    return lines
  elseif o.eqnum == false or o.eqnum == true then
    -- The environment will turn numbering on or off
    return lines
  else
    -- o.eqnum could be an integer (.o eqnum 4) or string (.o eqnum 1 3 4).
    local numbers
    if type(o.eqnum) == 'number' then
      numbers = { o.eqnum }
    else
      numbers = lbt.util.space_split(o.eqnum):map(tonumber)
    end
    numbers = pl.Set(numbers)
    local result = pl.List()
    local count = 0  -- number of actual math lines we've seen (not \intertext)
    for i = 1, #lines do
      if impl.is_text_line(lines[i]) then
        -- this does not 'count' as an equation line
        result[i] = lines[i]
      else
        count = count + 1
        if numbers[count] then
          result[i] = lines[i]
        else
          result[i] = lines[i] .. [[ \notag ]]
        end
      end
    end
    return result
  end
end

function impl.is_text_line(line)
  return line:startswith('\\intertext') or line:startswith('\\shortintertext')
end

function impl.environment_plain_or_starred(spec, envname, o, kw)
  local type = spec.type
  if type == 'inner' then
    return envname
  elseif type == 'outer' and o.eqnum then
    return envname
  elseif type == 'outer' and spec.apply_label and kw.label then
    return envname
  elseif type == 'outer' and not o.eqnum then
    return envname .. '*'
  elseif type == 'composite' and o.eqnum or kw.label then
    return envname
  elseif type == 'composite' and not o.eqnum then
    return envname .. '*'
  else
    return 'UNKNOWN'
  end
end

function impl.apply_line_endings(lines, o)
  local g = function(x, i)
    if impl.is_text_line(x) then    -- no \\ on a text line
      return x
    elseif i == lines:len() then    -- no \\ on the last line
      return x
    elseif o.linespace then
      return x .. F([[\\[%s] ]], o.linespace)
    else
      return x .. [[\\]]
    end
  end
  local result = pl.List()
  for i = 1, #lines do
    result:append(g(lines[i], i))
  end
  return result
end

--------------------------------------------------------------------------------

function impl.join_lines(lines, o)
  if o.linespace then
    return lines:concat(F([[\\[%s]%s]], o.linespace, '\n'))
  else
    return lines:concat(' \\\\ \n')
  end
end

function impl.apply_label_to_body(body, spec, o)
  if spec.apply_label and o.label then
    return body .. F('\n \\label{%s}', o.label)
  else
    return body
  end
end

function impl.append_text_to_body(body, spec)
  if spec.append_after_inner_env then
    return body .. spec.append_after_inner_env
  else
    return body
  end
end

--------------------------------------------------------------------------------

function impl.apply_margin_adjustment(block, spec, o)
  if spec.leftalign then
    return lbt.util.wrap_environment { block, 'adjustwidth', args = {o.leftmargin, ''} }
  else
    return block
  end
end

--------------------------------------------------------------------------------

local SpecialFunctions = {
  continuation = function(lines, o, _)
    local moveleft = function(line) return F([[ :: \MoveEqLeft %s]], line) end
    local quad     = function(line) return F([[ :: \quad &%s]], line:strip()) end
    local phantom  = function(line) return F([[ :: &\phantom{=\ } %s]], line) end
    local lbt_code = T {
      [[!MATH! .o alignat, ncols = 1, eqnum = !EQNUM!]],
      moveleft(lines[1]),
      quad(lines[2]),
      lines:slice(3,-1):map(phantom):concat('\n'),
      values = {
        MATH = o.eqnum and 'MATH' or 'MATH*',
        EQNUM = o.eqnum and #lines or 'false'
      }
    }
    local latex_code = lbt.util.lbt_commands_text_into_latex(lbt_code)
    return latex_code
  end,

  commentary = function(lines, o, _)
    local process = function(line)
      local x = lbt.parser.parse_math_commentary_line(line) or {}
      if not x.expr then
        lbt.err.E002_general('MATH commentary: no expression in line "%s"', line)
      end
      local result = ':: ' .. x.expr:strip()
      -- We unconditionally add \text to each line, even if the text is empty, because
      -- it means the text is aligned sympathetically with the longest expression.
      result = result .. F([[   \qquad && \text{%s}]], x.comment:strip())
      if x.tag ~= '' then
        result = result .. F([[   \tag{%s}]], x.tag)
      end
      lbt.debuglog('MATH commentary input and output')
      lbt.debuglog('in>  ' .. line)
      lbt.debuglog('out> ' .. result)
      return result
    end
    local lbt_code = T {
      [[!MATH! .o alignat, ncols = 2, eqnum = !EQNUM!]],
      lines:map(process):concat('\n'),
      values = {
        MATH = o.eqnum and 'MATH' or 'MATH*',
        EQNUM = o.eqnum and #lines or 'false'
      }
    }
    local latex_code = lbt.util.lbt_commands_text_into_latex(lbt_code)
    return latex_code
  end
}

function impl.math_impl_special(spec, args, o, kw)
  local result
  local func = SpecialFunctions[spec.name]
  if func then
    result = func(args, o, kw)
  else
    result = [[\lbtWarning{MATH command -- couldn't determine environment}]]
  end
  return result
end

------------- Module --------------------------------------------

return {
  Opargs = Opargs,
  MATH   = MATH
}
