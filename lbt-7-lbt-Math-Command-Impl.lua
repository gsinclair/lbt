
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
    environment_argument = 'cols'
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
    selective_numbering = false
  },

  eqgathered = {
    name = 'eqgathered',
    type = 'composite',
    env = 'gathered',
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
    environment_argument = 'cols',
    apply_label = false,
    selective_numbering = true,
    append_after_inner_env = '&&',
    leftalign = true
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
  -- virtual environments
  leftsplit = false, leftalign = false, leftalignat = false,
  -- numbering
  eqnum = false,
  -- simplemath
  sm = true,
  -- arguments to environments
  cols = 'nil',
  -- appearance
  spreadlines = 'nil', starred = false, par = true, leftmargin = '2em',
  -- debugging
  debugmath = false,
}
local MATH = function(_, args, o, kw)
  if o.starred then o:_set_local('par', false) end
  local spec = impl.math_spec(o)
  local result
  if spec then
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
  local lines, result
  -- The args are lines of mathematics. Apply simplemath to them, and
  -- whatever 'notag' commands are required to get the numbering right.
  lines = impl.apply_simplemath(args, o)
  lines = impl.apply_notag(lines, spec, o)
  -- The main work is done here, based on whether the chosen environment is
  -- inner, outer, or composite.
  if spec.type == 'inner' then
    result = impl.inner_environment_expansion(spec, lines, o, kw)
  elseif spec.type == 'outer' then
    result = impl.outer_environment_expansion(spec, lines, o, kw)
  elseif spec.type == 'composite' then
    result = impl.composite_environment_expansion(spec, lines, o, kw)
  else
    return F([[\lbtWarning{not implemented yet: %s}]], spec.name or spec.env)
  end
  -- Apply final formatting touches. The user might wants the lines spread out.
  -- And if it's a left-aligned equation, we probably want to adjust the margin.
  result = impl.apply_spreadlines(result, o)
  result = impl.apply_margin_adjustment(result, spec, o)
  -- And we're done.
  return result
end

-- Inner environment has a very simple Implementation.
function impl.inner_environment_expansion(spec, lines, o, kw)
  local body = impl.join_lines(lines)
  return impl.wrap_environment(body, spec.env, spec, o)
end

-- Outer environment needs to determine whether to use starred environment.
function impl.outer_environment_expansion(spec, lines, o, kw)
  local body = impl.join_lines(lines)
  local environment = impl.environment_plain_or_starred(spec, spec.env, o, kw)
  return impl.wrap_environment(body, environment, spec, o)
end

-- Composite environment does a simple inner and a possibly starred outer.
function impl.composite_environment_expansion(spec, lines, o, kw)
  local body = impl.inner_environment_expansion(spec, lines, o, kw)
  body = impl.apply_label_to_body(body, spec, kw)
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

function impl.apply_simplemath(lines, o)
  if o.sm then
    return lines:map(function(x) return F([[\sm{%s}]], x) end)
  else
    return lines
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
    for i=1,#lines do
      if numbers[i] then
        result[i] = lines[i]
      else
        result[i] = lines[i] .. [[ \notag ]]
      end
    end
    return result
  end
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

--------------------------------------------------------------------------------

function impl.join_lines(lines)
  return lines:concat(' \\\\ \n')
end

function impl.apply_label_to_body(body, spec, kw)
  if spec.apply_label and kw.label then
    return body .. F('\n \\label{%s}', kw.label)
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

function impl.apply_spreadlines(block, o)
  if o.spreadlines then
    return lbt.util.general_formatting_wrap(block, o, 'spreadlines')
  else
    return block
  end
end

function impl.apply_margin_adjustment(block, spec, o)
  if spec.leftalign then
    return lbt.util.wrap_environment { block, 'adjustwidth', args = {o.leftmargin, ''} }
  else
    return block
  end
end

------------- Module --------------------------------------------

return {
  Opargs = Opargs,
  MATH   = MATH
}
