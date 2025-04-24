
-- Template class
--
--  * Template.new(details)
--  * Template.object_by_name(tn)
--  * Template.object_by_name_or_nil(tn)
--  * Template.path_by_name(tn, notfound)
--  * t:register(path)
--  * t:command_details(opcode)        [maybe - not properly considered yet]
--
--  * [expand_directory -- an implementation detail]
--  * [template_names_to_logfile -- for debugging]
--  * [template_register_to_logfile -- for debugging]
--  * [template_compact_representation -- for debugging]
--------------------------------------------------------------------------------

local F = string.format

-- Class for storing and providing access to parsed content.
-- The actual parsing is done in lbt.parser and the result (pc0) is fed in
-- here. We generate an index to facilitate lookups.
local Template = {}
Template.mt = { __index = Template }
local impl = {}

-- {{{ new and register

function Template.new(template_spec, path)
  lbt.assert_table(1, template_spec)
  local spec = template_spec
  local o = {
    type      = 'Template',
    name      = spec.name,
    desc      = spec.desc,
    path      = path,
    sources   = spec.sources or {},
    init      = spec.init,
    expand    = spec.expand,
    functions = spec.functions or {},
    posargs   = spec.posargs or {},
    opargs    = spec.opargs or {},
    kwargs    = spec.kwargs or {},
    macros    = spec.macros or {},
  }
  --
  local ok, err_detail = impl.template_details_are_valid(o)
  if not ok then
    lbt.err.E215_invalid_template_details(template_spec, path, err_detail)
  end
  --
  ok, o.posargs = impl.normalise_posarg_specifications(o.posargs)
  if not ok then lbt.err.E215_invalid_template_details(spec, path, o.posargs) end
  ok = impl.validate_oparg_specifications(o.opargs)
  if not ok then lbt.err.E215_invalid_template_details(spec, path, 'opargs') end
  ok = impl.validate_kwarg_specifications(o.opargs)
  if not ok then lbt.err.E215_invalid_template_details(spec, path, 'kwargs') end
  --
  setmetatable(o, Template.mt)
  return o
end

function Template:register()
  -- Check for a template already registered with the same name. (Warning only.)
  if Template.object_by_name_or_nil(self.name) ~= nil then
    local curr_path = Template.path_by_name(self.name)
    lbt.log(2, "WARN: Template name <%s> already exists; overwriting.", self.name)
    lbt.log(2, "       * existing path: %s", curr_path)
    lbt.log(2, "       * new path:      %s", self.path)
  end
  -- Register the template itself.
  lbt.system.template_register[self.name] = self
  -- Register all the commands in the template.
  lbt.system.command_register[self.name] = impl.command_register(self)
end

-- }}}

-- {{{ methods (command_spec, all_commands) -----------------------------------------

function Template:command_spec(opcode)
  return lbt.system.command_register[self.name][opcode]
end

function Template:command_register()
  return lbt.system.command_register[self.name]
end

-- }}}

-- {{{ static methods

function Template.object_by_name(tn)
  local t = lbt.system.template_register[tn]
  if t == nil then
    lbt.err.E200_no_template_for_name(tn)
  end
  return t
end

function Template.object_by_name_or_nil(tn)
  local t = lbt.system.template_register[tn]
  if t == nil then
    return nil
  end
  return t
end

function Template.path_by_name(tn)
  local t = lbt.system.template_register[tn]
  local path = t and t.path
  if path == nil then
    lbt.err.E200_no_template_for_name(tn)
  end
  return path
end

function Template.names_to_logfile()
  local tr = lbt.system.template_register
  lbt.log('templates', "")
  lbt.log('templates', "Template names currently loaded")
  lbt.log('templates', "")
  for name, t in pairs(tr) do
    local nfunctions = pl.tablex.size(t.functions)
    lbt.log('templates', " * %-20s (%d functions)", name, nfunctions)
  end
end

function Template.register_to_logfile()
  local tr = lbt.system.template_register
  lbt.log('templates', "")
  lbt.log('templates', "The template register appears below.")
  lbt.log('templates', "")
  for name, t in pairs(tr) do
    lbt.log('templates', " * " .. name)
    lbt.log('templates', t:compact_representation())
  end
end

-- TODO: reconsider the need for this
function Template:compact_representation()
  local t = self
  local src = pl.List(t.sources):join(',')
  local fun = '-F-'
  local sty = '-S-'
  local arg = '-A-'
  local s = F([[
      name:      %s
      path:      %s
      sources:   %s
      functions: %s
      opargs:    %s
      argspecs:  %s
  ]], t.name, t.path, src, fun, sty, arg)
  return s
end

-- }}}

-- {{{ functions that support implementation

impl.expand_directory = function (path)
  if path:startswith("PWD") then
    return path:replace("PWD", os.getenv("PWD"), 1)
  elseif path:startswith("HOME") then
    return path:replace("HOME", os.getenv("HOME"), 1)
  elseif path:startswith("TEXMF") then
    lbt.err.E001_internal_logic_error("not implemented")
  else
    lbt.err.E207_invalid_template_path(path)
  end
end

-- spec: a table created inside Template.new()
-- Return: ok, error_details
impl.template_details_are_valid = function (spec)
  if type(spec) ~= 'table' then
    return false, F('argument is not a table, it is a %s', type(spec))
  elseif type(spec.name) ~= 'string' then
    return false, F('name is not a string')
  elseif type(spec.desc) ~= 'string' or #spec.desc < 10 then
    return false, F('desc is not a string or is too short')
  elseif type(spec.sources) ~= 'table' then
    return false, F('sources is not a table')
  elseif spec.init and type(spec.init) ~= 'function' then
    return false, F('init is not a function')
  elseif spec.expand and type(spec.expand) ~= 'function' then
    return false, F('expand is not a function')
  elseif type(spec.functions) ~= 'table' then
    return false, F('functions is not a table')
  elseif type(spec.posargs) ~= 'table' then
    return false, F('posargs is not a table')
  elseif type(spec.opargs) ~= 'table' then
    return false, F('opargs is not a table')
  elseif type(spec.kwargs) ~= 'table' then
    return false, F('kwargs is not a table')
  elseif type(spec.macros) ~= 'table' then
    return false, F('macros is not a table')
  end
  return true, ''
end

-- Turn '1+' into { 1, 9999 } and 3 (note number not string) into { 3, 3 }
-- and '2-4' into { 2, 4 }.
-- Return nil if it's an invalid type or format.
local convert_argspec = function(x)
  if type(x) ~= 'number' and type(x) ~= 'string' then
    return nil
  end
  if type(x) == 'number' then
    return { x, x }
  end
  local m, n
  n = x:match('^(%d+)$')
  if n then
    return { tonumber(n), tonumber(n) }
  end
  n = x:match('^(%d+)[+]$')
  if n then
    return { tonumber(n), 9999 }
  end
  m, n = x:match('^(%d+)-(%d+)$')
  if m and n then
    return { tonumber(m), tonumber(n) }
  end
  -- If we get this far, the spec is not valid.
  return nil
end

-- Apply `convert_argspec` (see above) to each token in the input.
-- Return true, {...} if good and false, error_details if bad.
impl.normalise_posarg_specifications = function (specs)
  local result = {}
  for token, x in pairs(specs) do
    local spec = convert_argspec(x)
    if spec then
      result[token] = spec
    else
      return false, F('argument specification <%s> invalid for <%s>', x, token)
    end
  end
  return true, result
end

-- Each key needs to be a string, and each value needs to be a table, where each
-- key is a string.
impl.validate_oparg_specifications = function(spec)
  -- helper function
  local table_with_all_keys_string = function(x)
    if type(x) ~= 'table' then return false end
    for k, _ in pairs(x) do
      if type(k) ~= 'string' then return false, 'key '..k end
    end
    return true
  end
  -- implementation
  if not table_with_all_keys_string(spec) then return false, 'invalid table structure' end
  for _, v in pairs(spec) do
    if not table_with_all_keys_string(v) then return false end
  end
  return true
end

impl.validate_kwarg_specifications = function(spec)
  return true
end

-- input: a Template
-- output: a command register {
--   VSPACE = {
--     opcode  = 'VSPACE',
--     fn      = <function>,
--     posargs = { 1, 1 },
--     opargs  = { starred = false },
--     kwargs  = {},
--     source  = 'lbt.Basic'
--   },
--   VSPACE* = {
--     opcode = 'VSPACE*',
--     refer  = 'VSPACE'
--   },
--   ...
-- }
--
-- Starred commands like VSPACE* are generated by noticing that VSPACE has a
-- 'starred' oparg.
impl.command_register = function(t)
  local reg = pl.Map()
  for opcode, fn in pairs(t.functions) do
    -- (1) Add this opcode to the register
    reg[opcode] = lbt.core.CommandSpec.new {
      opcode  = opcode,
      starred = false,
      fn      = fn,
      posargs = t.posargs[opcode],
      opargs  = t.opargs[opcode],
      kwargs  = t.kwargs[opcode],
      source  = t.name
    }
    -- (2) Add a starred version to the register, if appropriate
    if t.opargs[opcode] and (t.opargs[opcode].starred ~= nil) then
      local opcode_star = opcode .. '*'
      reg[opcode_star] = lbt.core.CommandSpec.new {
        opcode  = opcode_star,
        starred = true,
        refer   = opcode,
        fn      = fn,
        posargs = t.posargs[opcode],
        opargs  = t.opargs[opcode],
        kwargs  = t.kwargs[opcode],
        source  = t.name
      }
    end
  end
  return reg
end

-- }}}

lbt.fn.Template = Template
