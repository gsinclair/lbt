
-- Template class
--
--  * Template.new(details)
--  * Template.object_by_name(tn, notfound)
--  * Template.path_by_name(tn, notfound)
--  * t:register(path)
--  * t:command_details(opcode)        [maybe - not properly considered yet]
--
--  * [expand_directory -- an implementation detail]
--  * [template_names_to_logfile -- for debugging]
--  * [template_register_to_logfile -- for debugging]
--  * [template_compact_representation -- for debugging]
--------------------------------------------------------------------------------

-- Class for storing and providing access to parsed content.
-- The actual parsing is done in lbt.parser and the result (pc0) is fed in
-- here. We generate an index to facilitate lookups.
local Template = {}
local impl = {}

-- template_details (td): table with name, desc, init, expand, ...
--                        {returned by template files like Basic.lua}
-- path: filesystem path where this template was loaded, used to give
--       the user good information if the same name is loaded twice.
function Template.register(template_details, path)
  local td = template_details
  local tn = template_details.name
  local ok, err_detail, x   -- (needed throughout the function)
  -- (1) Fill some gaps for things that don't have to be filled in.
  td.functions       = td.functions       or {}
  td.arguments       = td.arguments       or {}
  td.default_options = td.default_options or {}
  td.macros          = td.macros          or {}
  -- (2) Check for errors in the spec.
  ok, err_detail = impl.template_details_are_valid(td)
  if ok then
    if Template.object_by_name(tn) ~= nil then
      local curr_path = Template.path_by_name(tn, 'error')
      lbt.log(2, "WARN: Template name <%s> already exists; overwriting.", tn)
      lbt.log(2, "       * existing path: %s", curr_path)
      lbt.log(2, "       * new path:      %s", path)
    end
    lbt.system.template_register[tn] = { td = td, path = path }
  else
    lbt.err.E215_invalid_template_details(td, path, err_detail)
  end
  -- (3) Normalise some of the specified values.
  --
  -- Having cleared the hurdles so far and registered the template,
  -- we now act on the argument specification and turn it into
  -- something that can be used at expansion time.
  ok, x = impl.template_arguments_specification(td.arguments)
  if ok then
    td.arguments = x
  else
    lbt.err.E215_invalid_template_details(td, path, x)
  end
  -- Likewise with default options. They are specified as strings and need to be
  -- turned into a map.
  -- Update Oct 2024: I am supporting a new way of specifying default options,
  -- which this function will need to support.
  ok, x = impl.template_normalise_default_options(td.default_options)
  if ok then
    td.default_options = x
  else
    lbt.err.E215_invalid_template_details(td, path, x)
  end
  return nil
end

function Template.object_by_name(tn, notfound)
  local te = lbt.system.template_register[tn]    -- template entry
  local td = te and te.td
  if td == nil and notfound == 'error' then
    lbt.err.E200_no_template_for_name(tn)
  end
  return td
end

function Template.path_by_name(tn, notfound)
  local te = lbt.system.template_register[tn]    -- template entry
  local tp = te and te.path
  if tp == nil and notfound == 'error' then
    lbt.err.E200_no_template_for_name(tn)
  end
  return tp
end

function Template.names_to_logfile()
  local tr = lbt.system.template_register
  lbt.log('templates', "")
  lbt.log('templates', "Template names currently loaded")
  lbt.log('templates', "")
  for name, te in pairs(tr) do
    local nfunctions = #(te.td.functions)
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
    local x = lbt.fn.template_compact_representation(t)
    lbt.log('templates', x)
  end
end

-- TODO: reconsider the need for this
function Template.compact_representation(te)
  local t = te.td
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
  ]], t.name, te.path, src, fun, sty, arg)
  return s
end

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

-- Return: ok, error_details
impl.template_details_are_valid = function (td)
  if type(td) ~= 'table' then
    return false, F('argument is not a table, it is a %s', type(td))
  elseif type(td.name) ~= 'string' then
    return false, F('name is not a string')
  elseif type(td.desc) ~= 'string' or #td.desc < 10 then
    return false, F('desc is not a string or is too short')
  elseif type(td.sources) ~= 'table' then
    return false, F('sources is not a table')
  elseif td.init and type(td.init) ~= 'function' then
    return false, F('init is not a function')
  elseif td.expand and type(td.expand) ~= 'function' then
    return false, F('expand is not a function')
  elseif type(td.functions) ~= 'table' then
    return false, F('functions is not a table')
  elseif type(td.arguments) ~= 'table' then
    return false, F('arguments is not a table')
  elseif type(td.default_options) ~= 'table' then
    return false, F('default_options is not a table')
  elseif type(td.macros) ~= 'table' then
    return false, F('macros is not a table')
  end
  return true, ''
end

-- Turn '1+' into { spec = '1+', min = 1, max = 9999 } and
-- 3 (not number not string) into { spec = '3', min = 3, max = 3 }.
-- Return nil if it's an invalid type or format.
local convert_argspec = function(x)
  if type(x) == 'number' then
    return { spec = ''..x, min = x, max = x }
  elseif type(x) ~= 'string' then
    return nil
  end
  local m, n
  n = x:match('^(%d+)$')
  if n then
    return { spec = x, min = tonumber(n), max = tonumber(n) }
  end
  n = x:match('^(%d+)[+]$')
  if n then
    return { spec = x, min = tonumber(n), max = 9999 }
  end
  m, n = x:match('^(%d+)-(%d+)$')
  if m and n then
    return { spec = x, min = tonumber(m), max = tonumber(n) }
  end
  return nil
end

-- Apply `convert_argspec` (see above) to each token in the input.
-- Return true, {...} if good and false, error_details if bad.
impl.template_arguments_specification = function (arguments)
  local result = {}
  for token, x in pairs(arguments) do
    local spec = convert_argspec(x)
    if spec then
      result[token] = spec
    else
      return false, F('argument specification <%s> invalid for <%s>', x, token)
    end
  end
  return true, result
end

-- In a template like lbt-Basic.lua, each command potentially has optional arguments,
-- like   ALIGN .o spreadlines=1em, nopar :: ...
-- These opargs need to have default values, specified in the template like so:
--   [method 1]
--     o:append 'ALIGN.spreadlines = 2pt, ALIGN.nopar = false'
--     {this method relies on lbt.parser.parse_dictionary}
--   [method 2]
--     o:append { 'ALIGN', spreadlines = '2pt', nopar = false }
--     {this method is less repetitive}
--
-- The input to template_normalise_default_options is a pl.List of option specs,
-- each of which can be a string (method 1) or a table (method 2).
--
-- We normalise these into a combined table of default options.
-- The output is a map
--   { 'ALIGN.spreadlines' = '2pt', 'ALIGN.nopar' = false, 'ITEMIZE.compact = false', ... }
--
-- Return  true, output   or   false, error string
--
-- XXX: This will change: I am changing the way opargs specs are stored.
-- I might also enforce the newer method of specifying opargs in the template; we'll see.
--   local op = {}
--   ...
--   op.TEXT = { starred = false, par = true }
--
impl.template_normalise_default_options = function (xs)
  -- Example input: 'ALIGN.spreadlines = 2pt, ALIGN.nopar = false'
  local method1 = function(s)
    return lbt.parser.parse_dictionary(s)
  end
  -- Example input: { 'ALIGN', spreadlines = '2pt', nopar = false }
  local method2 = function(t) -- input is a table
    local options = pl.Map()
    local command = t[1]
    local stat = false
    for k,v in pairs(t) do
      k = command .. '.' .. k
      options[k] = v
      stat = stat or true  -- we want to encounter at least one option
    end
    stat = stat and (command ~= nil)
    return stat, options
  end
  -- Function begins here
  local result = pl.Map()
  for x in pl.List(xs):iter() do
    if type(x) == 'string' then
      local opts = method1(x)
      if opts then result:update(opts)
      else return false, x
      end
    elseif type(x) == 'table' then
      local ok, opts = method2(x)
      if ok then result:update(opts)
      else return false, x
      end
    else
      lbt.err.E581_invalid_default_option_value(x)
    end
  end
  return true, result
end


-- }}}

lbt.fn.Template = Template
