--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

-- {{{ Preamble: local conveniences
local F = string.format

local ENI = function()
  error("Not implemented", 3)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ ParsedContent class
--
--  * ParsedContent.new(pc0, pragmas)
--  * pc:meta()
--  * pc:title()
--  * pc:dict_or_nil(name)
--  * pc:list_or_nil(name)
--  * pc:template_name()
--  * pc:template_object()
--  * pc:extra_sources()
--  * pc:local_options()
--  * pc:toString()       -- a compact representation
--------------------------------------------------------------------------------

-- Class for storing and providing access to parsed content.
-- The actual parsing is done in lbt.parser and the result (pc0) is fed in
-- here. We generate an index to facilitate lookups.
local ParsedContent = {}
ParsedContent.mt = { __index = ParsedContent }

local mkindex = function(pc0)
  local result = { dicts = {}, lists = {} }
  for _, x in ipairs(pc0) do
    if x.type == 'dict_block' then
      result.dicts[x.name] = x
    elseif x.type == 'list_block' then
      result.lists[x.name] = x
    end
  end
  return result
end

-- The idea of using metatables to build a class comes from Section 16.1 of the
-- free online 'Programming in Lua'.
function ParsedContent.new(pc0, pragmas)
  lbt.assert_table(1, pc0)
  lbt.assert_table(2, pragmas)
  local o = {
    type = 'ParsedContent',
    data = pc0,
    index = mkindex(pc0),
    pragmas = pragmas
  }
  setmetatable(o, ParsedContent.mt)
  return o
end

-- Return a dictionary given a name. The actual keys and values are returned
-- in a table, not all the metadata that is stored in pc0.
function ParsedContent:dict_or_nil(name)
  local d = self.index.dicts[name]
  return d and d.entries
end

-- Return a list given a name. The actual values are returned in a table, not
-- all the metadata that is stored in pc0.
function ParsedContent:list_or_nil(name)
  local l = self.index.lists[name]
  return l and pl.List(l.commands)
end

-- Return the META dictionary block, or raise an error if it doesn't exist.
function ParsedContent:meta()
  local m = self:dict_or_nil('META')
  return m or lbt.err.E976_no_META_field()
end

-- Return the TITLE value from the META block, or '(no title)' if it doesn't exist.
function ParsedContent:title()
  return self:meta().TITLE or '(no title)'
end

function ParsedContent:template_name()
  return self:meta().TEMPLATE
end

function ParsedContent:template_object_or_error()
  local tn = self:template_name()
  local t = lbt.fn.template_object_or_error(tn)
  return t
end

function ParsedContent:extra_sources()
  return self:meta().SOURCES or {}
end

function ParsedContent:local_options()
  local options = self:meta().OPTIONS or self:meta().STYLES
  if type(options) == 'table' then
    return options
  elseif type(options) == 'string' then
    return lbt.fn.style_string_to_map(styles)
  else
    return pl.Map()
  end
end

-- }}}

--------------------------------------------------------------------------------
-- {{{ OptionLookup class
--
--  * OptionLookup.new { document_wide = ..., document_narrow = ..., sources = ...}
--  * o:set_opcode_and_options(opcode, options)
--  * o:unset_opcode_and_options()
-- 
-- Then use like so:
--   ol = OptionLookup.new {...}
--   ol:set_opcode_and_options('ITEMIZE', {compact=true})
--   ...
--   if ol.compact then ... end
--   if ol['vector.format'] == 'bold' then ... end
--   ...
--   ol:unset_opcode_and_options()
--------------------------------------------------------------------------------

local OptionLookup = {}
local _sources_ = {}   -- template defaults
local _wide_    = {}   -- document-wide options   (from \lbtOptions)
local _narrow_  = {}   -- document-narrow options (from META.OPTIONS)
local _cache_   = {}
local _opcode_  = {}   -- e.g. 'ITEMIZE'
local _local_   = {}   -- command-local options (not provided on initialisation)
local _err_     = lbt.err.E190_invalid_OptionLookup

-- OptionLookup.new {
--   document_wide   = (dictionary of options)
--   document_narrow = (dictionary of options)
--   sources         = (list of template objects)
-- }
--
-- We store the wide, narrow and sources information for our future use.
-- We initialise an empty cache for future speedy access to information.
-- We initialise an opcode to nil. In future, when we want to resolve a key
-- (say, o.color), we need to know what opcode is at play. Are we looking
-- for TEXT.color or QQ.color or ...?
OptionLookup.new = function(t)
  local o      = {}
  o[_wide_]    = t.document_wide   or _err_('document_wide')
  o[_narrow_]  = t.document_narrow or _err_('document_narrow')
  o[_sources_] = t.sources         or _err_('sources')
  o[_cache_]   = {}
  o[_opcode_]  = nil   -- 'ITEMIZE', provided later
  o[_local_]   = nil   -- 'compact=true, bullet=>', provided later
  -- We need to put explicit methods in so that __index is not triggered.
  o.set_opcode_and_options = OptionLookup.set_opcode_and_options
  o.unset_opcode_and_options = OptionLookup.unset_opcode_and_options
  -- Apart from that, any field reference is handled by __index, to perform
  -- an option lookup.
  setmetatable(o, OptionLookup)
  return o
end

-- Call this before trying to resolve any options. The opcode needs to be known.
function OptionLookup:set_opcode_and_options(opcode, options)
  self[_opcode_] = opcode
  self[_local_]  = options
end

-- Call this after completing a command, to refresh the option lookup for later.
function OptionLookup:unset_opcode_and_options()
  self[_opcode_] = nil
  self[_local_]  = nil
end

-- Supporting option lookup below.
local qualified_key = function(ol, key)
  if key:find('%.') then
    return key
  elseif ol[_opcode_] then
    return ol[_opcode_] .. '.' .. key
  else
    lbt.err.E191_cannot_qualify_key_for_option_lookup(key)
  end
end

-- Supporting option lookup below.
local multi_level_lookup = function(ol, qk)
  local v
  -- 1. document-narrow
  v = ol[_narrow_][qk]
  if v then return v end
  -- 2. document-wide
  v = ol[_wide_][qk]
  if v then return v end
  -- 3. template defaults
  for t in pl.List(ol[_sources_]):reverse():iter() do
    v = t.default_options[qk]
    if v then return v end
  end
  -- 4. Nothing found
  return nil
end

-- Doing an option lookup is complex.
--  * First of all, the key is probably a simple one ('color') and needs to be
--    qualified ('QQ.color').
--  * Then, it might be set as a local option.
--  * Otherwise, it might be in the cache, from a previous access.
--  * Otherwise, it might be a document-narrow option.
--  * Otherwise, it might be a document-wide option.
--  * Otherwise, it might be a default in a template.
OptionLookup.__index = function(self, key)
  local qk = qualified_key(self, key)
  local v
  -- 1. Local option.
  if self[_local_] == nil then lbt.err.E193_no_local_options_to_look_up(qk) end
  v = self[_local_][key]
  if v then return v end
  -- 2. Cache.
  v = self[_cache_][qk]
  if v then return v end
  -- 3. Other.
  v = multi_level_lookup(self, qk)
  if v then
    self[_cache_][qk] = v
    return v
  else
    lbt.err.E192_option_lookup_failed(key)
  end
end

OptionLookup.__tostring = function(self)
  local x = pl.List()
  local add = function(fmt, ...)
    x:append(F(fmt, ...))
  end
  local pretty = function(x)
    if pl.tablex.size(x) == 0 then return '{}' else return pl.pretty.write(x) end
  end
  add('OptionLookup:')
  add('  opcode: %s', self[_opcode_])
  add('  local options: %s', pretty(self[_local_]))
  add('  cache: %s', pretty(self[_cache_]))
  return x:concat('\n')
end

-- }}}

--------------------------------------------------------------------------------
-- {{{ Author content:
--  * author_content_clear      (reset lbt.const and lbt.var data)
--  * author_content_append     (append line to lbt.const.author_content)
--------------------------------------------------------------------------------

lbt.fn.author_content_clear = function()
  lbt.log(4, "lbt.fn.author_content_clear()")
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.fn.author_content_append = function(line)
  -- NOTE we used to strip the line and handle » continuations here. That is
  -- no longer desirable or necessary. We can easily handle all » at once with
  -- string substitution. And stripping prevents us from supporting verbatim
  -- text like code listings.
  --
  -- The code and the comment will be deleted when the lpeg parsing approach
  -- is completed and the branch is merged.
  --
  -- line_list = lbt.const.author_content
  -- line = line:strip()
  -- if line == "" or line:startswith('%') then return end
  -- if line:sub(1,2) == "»" then
  --   -- Continuation of previous line
  --   prev_line = line_list:pop()
  --   if prev_line == nil then
  --     lbt.err.E103_invalid_line_continuation(line)
  --   end
  --   line = prev_line .. " " .. line:sub(3,-1)
  -- end
  lbt.const.author_content:append(line)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Processing author content and emitting Latex code
--  * parsed_content(c)        (internal representation of the author's content)
--  * latex_expansion(pc)      (Latex representation based on the parsed content)
--------------------------------------------------------------------------------


lbt.fn.parsed_content = function(content_lines)
  -- The content lines are in a list. For lpeg parsing, we want the content as
  -- a single string. But there could be pragmas in there like !DRAFT, and it
  -- is better to extract them now that we have separate lines. Hence we call
  -- a function to do this for us. This function handles » line continuations
  -- as well. It also removes comments lines. This is a pre-parsing stage.
  local pragmas, content = lbt.fn.impl.pragmas_and_content(content_lines)
  -- Detect ignore and act accordingly.
  if pragmas.ignore then
    return ParsedContent.new(nil, pragmas)
  end
  -- Detect debug and act accordingly.
  if pragmas.debug then
    lbt.fn.set_log_channels_for_debugging_single_expansion()
  end
  -- Now we are ready to parse the actual content, courtesy of lbt.parser.
  if content:find('[@META]', 1, true) then
    -- we're good
  else
    content = content:gsub('@META', '[@META]')
    content = content:gsub('+BODY', '[+BODY]')
  end
  local x = lbt.parser.parsed_content_0(content)
  if x.ok then
    lbt.log('parse', 'Content parsed with lbt.parser.parsed_content_0. Result:')
    lbt.log('parse', pl.pretty.write(x.pc0))
    return ParsedContent.new(x.pc0, pragmas)
  else
    lbt.err.E110_unable_to_parse_content(content, x.maxposition)
  end
end

-- old code - still needed?
lbt.fn.validate_parsed_content = function (pc)
  -- We check that META and META.TEMPLATE are present.
  if pc:meta() == nil then
    lbt.err.E203_no_META_defined()
  end
  if pc:template_name() == nil then
    lbt.err.E204_no_TEMPLATE_defined()
  end
  return nil
end

-- Returns a List.
-- Updating in June 2024 to include a better OptionLookup instead of the style
-- resolver.
--
-- lbt.fn.latex_expansion(pc)
--
-- A very important function, turning parsed content into Latex, using the main
-- template and any extra chosen sources to resolve each command.
--
-- We need a template object t on which we call t.init() for any initialisation
-- and t.expand(pc, or, ol) to produce the Latex in line with the template's
-- implementation. (Consider that an Article, Exam and Worksheet template will
-- all produce different-looking documents, without even considering their
-- different contents.)
--
-- We need to know what sources are being used. The template itself will name
-- some, and the document may name more. Thus we have the helper function
-- consolidated_sources(pc, t) to produce a list of template objects in which
-- we can search for command implementations.
--
-- We need an opcode resolver ('ocr') so that 'ITEMIZE' in a document can be
-- resolved into a Lua function (template lbt.Basic -> functions -> ITEMIZE).
-- Thus we call the helper function opcode_resolver(sources). This returns a
-- function we can call to provide the template function for any opcode.
--
-- We need an option lookup ('ol') so that commands may have access to options
-- that are defined in various places: document-wide with \lbtOptions{...},
-- document-narrow with META.OPTIONS, and command-local with '.o ...'. For
-- example, 'QQ .o color=red :: Evaluate $3 \times 5$'. The implementation of
-- QQ needs to be able to access 'o.color' and 'o.vspace' easily. Thus we call
-- OptionLookup.new{...}.
--
-- With everything set up, we can call t.init() and t.expand(pc, or, ol).
--
-- We return a list of Latex strings, ready to be printed into the document at
-- compile time.
--
lbt.fn.latex_expansion = function (pc)
  local t = pc:template_object_or_error()
  local sources = lbt.fn.impl.consolidated_sources(pc, t)
  local ocr = lbt.fn.opcode_resolver(sources)
  local ol = OptionLookup.new {
    document_wide = lbt.system.document_wide_styles,
    document_narrow = pc:local_options(),
    sources = sources,
  }
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  lbt.log(4, 'About to latex-expand template <%s>', pc:template_name())
  local result = t.expand(pc, ocr, ol)
  lbt.log(4, ' ~> result has %d bytes', #result)
  return result
end


-- Returns a List.
lbt.fn.latex_expansion_old = function (parsed_content)
  local pc = parsed_content
  local t = pc:template_object_or_error()
  -- Obtain token and style resolvers so that expansion can occur.
  local tr, sr = lbt.fn.token_and_style_resolvers(pc)
  -- Store the token and style resolvers for potential use by other functions.
  lbt.const.token_resolver = tr
  lbt.const.style_resolver = sr
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  lbt.log(4, 'About to latex-expand template <%s>', pc:template_name())
  local result = t.expand(pc, tr, sr)
  lbt.log(4, ' ~> result has %d bytes', #result)
  return result
end

-- Return List of strings, each containing Latex for a line of author content.
-- If a line cannot be evaluated (no function to support a given token) then
-- we insert some bold red information into the Latex so the author can see,
-- rather than halt the processing.
--
-- commands: List of parsed commands like {'TEXT', o = {}, k = {}, a = {'Hello'}}
-- ocr:      opcode resolver         call ocr('Q') to get function for opcode Q
-- ol:       option lookup           call o.color to get option for current opcode
--                                   or o['Q.color'] to be specific
--
-- TODO rename this function to `latex_for_commands`.
--      (That means changing several template expand functions.)
lbt.fn.parsed_content_to_latex_multi = function (commands, ocr, ol)
  local buffer = pl.List()
  for command in commands:iter() do
    local status, latex = lbt.fn.latex_for_command(command, ocr, ol)
    if status == 'ok' then
      buffer:append(latex)
    elseif status == 'notfound' then
      local msg = lbt.fn.impl.latex_message_token_not_resolved(command[1])
      buffer:append(msg)
    elseif status == 'error' then
      local err = latex
      local msg = lbt.fn.impl.latex_message_token_raised_error(command[1], err)
      buffer:append(msg)
    end
  end
  return buffer
end

-- Take a single command of parsed author content like
--   { 'ITEMIZE', o = { float = true}, k = {}, a = {'One', 'Two', 'Three'} }
-- and produce a string of Latex.
--
-- Before sending the arguments to the opcode function, any register references
-- like ◊ABC are expanded. Also, STO is treated specially. And, in the future,
-- CTRL.
--
-- Parameters:
--  * command: parsed author content
--  * or:      an opcode resolver that we call to get an opcode function
--  * ol:      an options lookup that we pass to the function
--
-- Return:
--  * 'ok', latex       [succesful]
--  * 'sto', nil        [STO register allocation]
--  * 'notfound', nil   [opcode not found among sources]
--  * 'error', details  [error occurred while processing command]
--
-- Side effect:
--  * lbt.var.line_count is increased (unless this is a register allocation)
--  * lbt.var.registers might be updated
lbt.fn.latex_for_command = function (command, ocr, ol)
  lbt.log(4, 'latex_for_command: %s', pl.pretty.write(command))
  lbt.log('emit', '')
  lbt.log('emit', 'Line: %s', pl.pretty.write(command))
  local opcode = command[1]
  local args  = command.a
  local nargs = #args
  -- 1. Handle a register allocation. Do not increment command count.
  if opcode == 'STO' then
    lbt.fn.impl.assign_register(args)
    return 'sto', nil
  end
  -- 2. Search for an opcode function (and argspec) and return if we did not find one.
  local x = ocr(opcode)   --> { opcode_function = ..., argspec = ... }
  if x == nil then
    lbt.log('emit', '    --> NOTFOUND')
    lbt.log(2, 'opcode not resolved: %s', opcode)
    return 'notfound', nil
  end
  -- 3. Check we have a valid number of arguments.
  if x.argspec then
    local a = x.argspec
    if nargs < a.min or nargs > a.max then
      local msg = F("%d args given but %s expected", nargs, a.spec)
      lbt.log('emit', '    --> ERROR: %s', msg)
      lbt.log(1, 'Error attempting to expand opcode:\n    %s', msg)
      return 'error', msg
    end
  end
  -- 4. We really are processing a command, so we can increase the command_count.
  lbt.fn.impl.inc_command_count()
  -- 5. Expand register references where necessary.
  --    We are not necessarily in mathmode, hence false.
  args = args:map(lbt.fn.impl.expand_register_references, false)
  -- 6. Call the opcode function and return 'ok', ... or 'error', ...
  local in_development = true -- (June 2024 changes)
  local result
  if in_development then
    -- local o = lbt.fn.options_resolver(command.o)
    ol:set_opcode_and_options(opcode, command.o)
    local k = command.k
    result = x.opcode_function(nargs, args, ol, k)
    ol:unset_opcode_and_options()
  else
    result = opcode_function(nargs, args, sr)
  end
  if type(result) == 'string' then
    lbt.log('emit', '    --> %s', result)
    return 'ok', result
  elseif type(result) == 'table' and type(result.error) == 'string' then
    local errormsg = result.error
    lbt.log('emit', '    --> ERROR: %s', errormsg)
    lbt.log(1, 'Error occurred while processing opcode %s\n    %s', opcode, errormsg)
    return 'error', errormsg
  elseif type(result) == 'table' then
    result = table.concat(result, "\n")
    lbt.log('emit', '    --> %s', result)
    return 'ok', result
  else
    lbt.err.E325_invalid_return_from_template_function(opcode, result)
  end
end

-- From one parsed-content object, we can derive a token resolver and a style
-- resolver.
lbt.fn.token_and_style_resolvers = function (pc)
  -- The name of the template allows us to retrieve the template object.
  local t = pc:template_object_or_error()
  -- From the pc we can look for added sources. The template object has sources
  -- too. So we can calculate "consolidated sources".
  local src = lbt.fn.impl.consolidated_sources(pc, t)
  -- Styles can come from three places: doc-wide, written into the content,
  -- and from the consolidated sources that are in use. 
  local sty = lbt.fn.impl.consolidated_styles(lbt.system.document_wide_styles, pc, src)
  -- With consolidated sources and styles, we can make the resolvers.
  local tr = lbt.fn.token_resolver(src)
  local sr = lbt.fn.style_resolver(sty)
  return tr, sr
end

-- Produce a function that resolves tokens using the sources provided here.
-- This means the sources don't need to be passed around.
--
-- As a bonus, a memoisation cache is used to speed up token resolution.
--
-- The resolver function returns (token_function, argspec) if a token function
-- is found among the sources, or nil otherwise. Note that argspec might
-- legitimately be nil, although we will put a warning in the log file.
--
-- TODO make this impl
lbt.fn.opcode_resolver = function (sources)
  return pl.utils.memoize(function (token)
    for s in sources:iter() do
      -- Each 'source' is a template object, with properties 'functions'
      -- and 'arguments'.
      local f = s.functions[token]
      local a = s.arguments[token]
      if f then
        if a == nil then
          lbt.log(2, 'WARN: no argspec provided for opcode <%s>', token)
        end
        return { opcode_function = f, argspec = a }
      end
    end
    -- No token function found :(
    return nil
  end)
end

-- Produce a function that resolves styles using global, template, and local
-- style information, as contained in the consolidated style_map parameter.
--
-- The resolver function takes a style key like 'Q.color' and returns a string
-- like 'RoyalBlue'. If there is no such style, a program-halting error occurs.
-- That's because the only place this resolver is called is in a token
-- expansion function, and if no style is found, it means the coder has
-- probably made a typo. They will want to know about it.
--
-- As a convenience for the template author, the resolver function can take
-- many keys and return many values. For example:
--
--   local col, vsp = sr('Q.color Q.vspace')        ->  'blue', '12pt'
--
-- TODO make this impl
lbt.fn.style_resolver = function (style_map)
  return function (multikeystring)
    local x = multikeystring    -- e.g. 'Q.vspace Q.color'
    local keys = pl.List(pl.utils.split(x, '[, ]%s*'))
    local result = pl.List()
    for k in keys:iter() do
      local value = style_map[k]
      if value then
        result:append(value)
      else
        lbt.err.E387_style_not_found(k)
      end
    end
    return table.unpack(result)
  end
end

-- NOTE This code is highly experimental. It is supposed to replace
-- style_resolver above, but it has not yet been beaten into shape.
--
-- Suppose we have a command
--   QQ .o color=blue, vspace=12pt :: In what year did \dots
-- 
-- Then this function gets called with:
--   options_resolver('QQ', {color='blue', vspace='12pt'})
--
-- It needs to:
--  * qualify the two options passed in so that they keys are QQ.color etc.
--  * return a function that will look up any style based on qualified key.
--    * that function looks in the following places, in order:
--      - local options
--             QQ .o color=blue, vspace=12pt
--      - a CTRL command (not yet implemented, only considered)
--      - the document's META settings, like
--             OPTIONS .d QQ.color=red, QQ.vspace=6pt
--      - whole-of-document settings:
--             \lbtSetOption{QQ.color=navy}
--      - the default for the template
--             o.QQ = { vspace = 6pt', color = 'blue'}'
lbt.fn.options_resolver = function (opcode, local_options)
  local qualified_local_options = pl.Map()
  for k, v in pairs(local_options) do
    k = F('%s.%s', opcode, k)
    qualified_local_options[k] = v
  end
  local lookup = function (key)
    local v
    -- 1. local options
    v = qualified_local_options[key]
    if v then return v end
    -- 2. a CRTL command (not implemented)
    -- 3. the META settings
    -- 4. \lbtSetOption{QQ.color=navy}
    -- 5. the default for the template
  end
  return function (multikeystring)
    local x = multikeystring    -- e.g. 'Q.vspace Q.color'
    local keys = pl.List(pl.utils.split(x, '[, ]%s*'))
    local result = pl.List()
    for k in keys:iter() do
      local value = style_map[k]
      if value then
        result:append(value)
      else
        lbt.err.E387_style_not_found(k)
      end
    end
    return table.unpack(result)
  end
end

-- }}}

--------------------------------------------------------------------------------
-- {{{ Functions to do with loading templates
--  * register_template(td, path)
--  * template_object_or_nil(name)
--  * template_object_or_error(name)
--  * template_path_or_nil(name)
--  * template_path_or_error(name)
--  *
--  * [expand_directory -- an implementation detail]
--  * [template_compact_representation -- for debugging]
--------------------------------------------------------------------------------

lbt.fn.expand_directory = function (path)
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

-- template_details (td): table with name, desc, init, expand, ...
--                        {returned by template files like Basic.lua}
-- path: filesystem path where this template was loaded, used to give
--       the user good information if the same name is loaded twice.
lbt.fn.register_template = function(template_details, path)
  local td = template_details
  local tn = template_details.name
  ok, err_detail = lbt.fn.impl.template_details_are_valid(td)
  if ok then
    if lbt.fn.template_object_or_nil(tn) ~= nil then
      local curr_path = lbt.fn.template_path_or_error(tn)
      lbt.log(2, "WARN: Template name <%s> already exists; overwriting.", tn)
      lbt.log(2, "       * existing path: %s", curr_path)
      lbt.log(2, "       * new path:      %s", path)
    end
    lbt.system.template_register[tn] = { td = td, path = path }
  else
    lbt.err.E215_invalid_template_details(td, path, err_detail)
  end
  -- Having cleared the hurdles so far and registered the template,
  -- we now act on the argument specification (if provided) and turn it into
  -- something that can be used at expansion time.
  if td.arguments then
    local ok, x = lbt.fn.impl.template_arguments_specification(td.arguments)
    if ok then
      td.arguments = x
    else
      lbt.err.E215_invalid_template_details(td, path, x)
    end
  end
  -- Likewise with default options. They are specified as strings and need to be
  -- turned into a map.
  local ok, x = lbt.fn.impl.template_normalise_default_options(td.default_options)
  if ok then
    td.default_options = x
  else
    lbt.err.E215_invalid_template_details(td, path, x)
  end
  return nil
end

lbt.fn.template_object_or_nil = function(tn)
  local te = lbt.system.template_register[tn]    -- template entry
  return te and te.td
end

lbt.fn.template_object_or_error = function(tn)
  local t = lbt.fn.template_object_or_nil(tn)
  if t == nil then
    lbt.err.E200_no_template_for_name(tn)
  end
  return t
end

lbt.fn.template_path_or_nil = function(tn)
  local te = lbt.system.template_register[tn]    -- template entry
  return te and te.path
end

lbt.fn.template_path_or_error = function(tn)
  local p = lbt.fn.template_path_or_nil(tn)
  if p == nil then
    lbt.err.E200_no_template_for_name(tn)
  end
  return p
end

lbt.fn.template_names_to_logfile = function()
  local tr = lbt.system.template_register
  lbt.log('templates', "")
  lbt.log('templates', "Template names currently loaded")
  lbt.log('templates', "")
  for name, te in pairs(tr) do
    local nfunctions = #(te.td.functions)
    lbt.log('templates', " * %-20s (%d functions)", name, nfunctions)
  end
end

lbt.fn.template_register_to_logfile = function()
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

lbt.fn.template_compact_representation = function(te)
  local x = pl.List()
  local t = te.td
  -- local src = lbt.fn.impl.sources_list_compact_representation(t.sources)
  local src = pl.List(t.sources):join(',')
  local fun = '-F-'
  local sty = '-S-'
  local arg = '-A-'
  local s = F([[
      name:      %s
      path:      %s
      sources:   %s
      functions: %s
      styles:    %s
      argspecs:  %s
  ]], t.name, te.path, src, fun, sty, arg)
  return s
end
--}}}

--------------------------------------------------------------------------------
-- {{{ Miscellaneous functions
--  * style_string_to_map(text)
--------------------------------------------------------------------------------

-- 'Q.color gray :: MC.alphabet roman'
--    --> { 'Q.color' = 'gray', 'MC.alphabet' = 'roman'}
--
-- Return type is a pl.Map, at least for now. This is probably helpful for
-- calling 'update'.
lbt.fn.style_string_to_map = function(text)
  local result = pl.Map()
  for style_string in lbt.util.double_colon_split(text):iter() do
    -- sty is something like 'Q.color PeachPuff'
    local key, val = table.unpack(lbt.util.space_split(style_string, 2))
    result[key] = val
  end
  return result
end

lbt.fn.set_log_channels_for_debugging_single_expansion = function ()
  lbt.var.saved_log_channels = pl.List(lbt.system.log_channels)
  lbt.system.log_channels = pl.List{'all'}
  lbt.log(0, "Debug mode set for this expansion; all channels activated")
end

lbt.fn.reset_log_channels_if_necessary = function ()
  if lbt.var.saved_log_channels then
    lbt.system.log_channels = lbt.var.saved_log_channels
    lbt.var.saved_log_channels = nil
    lbt.log(0, "Log channels restored after completion of expansion")
  end
end

lbt.fn.current_expansion_id = function ()
  return lbt.system.expansion_id
end

lbt.fn.next_expansion_id = function ()
  lbt.system.expansion_id = lbt.system.expansion_id + 1
  return lbt.system.expansion_id
end

lbt.fn.write_debug_expansion_file_if_necessary = function (content, pc, latex)
  if lbt.api.query_log_channels('emit') then
    pl.dir.makepath('dbg-tex')
    local eid = lbt.fn.current_expansion_id()
    local filename = F('dbg-tex/%d.tex', eid)
    local content = nil
    if type(latex) == 'string' then
      content = latex
    elseif type(latex) == 'table' then
      content = latex:concat('\n')
    end
    pl.file.write(filename, content)
  end
end

-- Input: \myvec=lbt.Math:vector
-- Output:  myvec,       lbt.Math,      vector
--         (latex macro, template name, function name)
--             lm           tn             fn
-- Error: if the text does not follow the correct format
lbt.fn.parse_macro_define_argument = function (text)
  local ERR = lbt.err.E109_invalid_macro_define_spec
  local lm, tn, fn = text:match('^(%a+*?)=([%w.]+):(%w+)')
  if not (lm and tn and fn) then
    ERR(text)
  end
  if not tn:match('^%a') then
    ERR(text)
  end
  return lm, tn, fn
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Functions assisting the implementation, part 1
-- These are lower-level in nature and just do one thing with the argument(s)
-- they are given.
--  * xxx
--  * xxx
--  * xxx
--  * xxx
--------------------------------------------------------------------------------

lbt.fn.impl = {}

local update_pragma_set = function(pragmas, setting)
  local p = setting
  if     p == 'DRAFT'    then pragmas.draft  = true
  elseif p == 'NODRAFT'  then pragmas.draft  = false
  elseif p == 'SKIP'     then pragmas.skip   = true
  elseif p == 'NOSKIP'   then pragmas.skip   = false
  elseif p == 'IGNORE'   then pragmas.ignore = true
  elseif p == 'NOIGNORE' then pragmas.ignore = false
  elseif p == 'DEBUG'    then pragmas.debug  = true
  elseif p == 'NODEBUG'  then pragmas.debug  = false
  else
    lbt.err.E102_invalid_pragma(p)
  end
end

-- Extract pragmas from the lines into a table.
-- Return a table of pragmas (draft, debug, ignore) and a consolidated string of
-- the actual content, with » line continations taken care of.
lbt.fn.impl.pragmas_and_content = function(input_lines)
  pragmas = { draft = false, ignore = false, debug = false }
  lines   = pl.List()
  for line in input_lines:iter() do
    p = line:match("!(%u+)%s*$")
    if p then
      update_pragma_set(pragmas, p)
    elseif line:match('^%s*%%') then
      -- ignore comment line
    else
      lines:append(line)
    end
  end
  local content = lines:concat('\n')
  -- Handle » line continuations, which would normally happen at the beginning
  -- of a line, but we will allow them at the end, or at both.
  content = content:gsub('»[ \t]*\n[ \t]*»', '')
  content = content:gsub('»[ \t]*\n[ \t]*', '')
  content = content:gsub('[ \t]*\n[ \t]*»', '')
  return pragmas, content
end

-- Validate that a content key like @META or +BODY comprises only upper-case
-- characters, except for the sigil, and is the only thing on the line.
-- Also, it must not already exist in the dictionary.
-- It is known before calling this that the first character is @ or +.
-- Return the key (META, BODY).
lbt.fn.impl.validate_content_key = function(line, dictionary)
  if line:find(" ") then
    lbt.err.E103_invalid_content_key(line, "internal spaces")
  end
  name = line:match("^.(%u+)$")
  if name == nil then
    lbt.err.E103_invalid_content_key(line, "name can only be upper-case letters")
  end
  return name
end

lbt.fn.impl.token_and_text = function (line)
  local x = pl.utils.split(line, '%s+', false, 2)
  return table.unpack(x)
end

-- A valid token must begin with a capital letter and contain only capital
-- letters, digits, and symbols. I would like to restrict the symbols to
-- tasteful ones like [!*_.], but perhaps that is too restricting, and it is
-- more hassle to implement.
lbt.fn.impl.valid_token = function (token)
  return token == token:upper()
end

-- lbt.fn.impl.consolidated_sources(pc,t)
-- 
-- A template itself has sources, starting with itself. For example, Exam might
-- rely on Questions and Figures. A specific expansion optionally has extra
-- sources defined in @META.SOURCES. The specific ones take precedence.
--
-- It is imperative that lbt.Basic appear somewhere, without having to be named
-- by the user. It might as well appear at the end, so we add it.
--
-- Return: a List of source template _objects_ in the order they should be referenced.
-- Error: if any template name cannot be resolved into a template object.
--
lbt.fn.impl.consolidated_sources = function (pc, t)
  local src1 = pc:extra_sources()    -- optional specific source names (List)
  local src2 = pl.List(t.sources)    -- source names baked in to the template (List)
  local sources = pl.List();
  do
    sources:extend(src1);
    sources:append(t.name)           -- the template itself has to go in there
    sources:extend(src2)
  end
  local result = pl.List()
  for name in sources:iter() do
    local t = lbt.fn.template_object_or_nil(name)
    if t then
      result:append(t)
    else
      lbt.err.E206_cant_form_list_of_sources(name)
    end
  end
  local basic = lbt.fn.template_object_or_error("lbt.Basic")
  result:append(basic)
  return result
end

-- lbt.fn.impl.consolidated_styles(docwide, pc, sources)
--
-- There are three places that styles can be defined.
--  * In templates, with code such as `s.Q = { vspace = '12pt', color = 'blue' }`
--  * Document-wide, with code such as `\lbtStyles{Q.vspace 30pt}`
--  * Expansion-local, with code such as `STYLES Q.color red :: MC.alphabet Roman`
--
-- The precedence is expansion-local, then document-wide, then the templates.
--
-- There are potentially many templates at play (the list of sources). In the
-- expansion, there can be only one STYLES setting. Document-wide, there can be
-- several `\lbtStyles` commands, but they all end up affecting the one piece
-- of data: `lbt.system.document_wide_styles`.
--
-- In this function we create a single dictionary (pl.Map) that contains all styles
-- set, respecing precedence. It will be used to resolve styles in all token
-- evaluations for the whole expansion.
--
-- Input:
--  * docwide        a Map of document-wide options (i.e. lbt.system.d_w_o)
--  * meta           a table of expansion-local options in META.OPTIONS
--  * templates      consolidated list of templates in precedence order
--                   (we extract the 'options' map from each)
-- 
-- Return:
--  * a pl.Map of all style mappings, respecting precedence
--
-- Errors:
--  * none that I can think of
--
lbt.fn.impl.consolidated_styles = function (docwide, meta, templates)
  lbt.log('styles', '')
  local result = pl.Map()
  local options
  for t in pl.List(templates):reverse():iter() do
    options = t.options or pl.Map()
    lbt.log('styles', 'extracting styles from <%s>: %s', s.name, styles)
    result:update(styles)
  end
  styles = docwide
  lbt.log('styles', 'extracting document-wide styles:', styles)
  result:update(styles)
  styles = pc:extra_styles()
  lbt.log('styles', 'extracting styles from document content: %s', styles)
  result:update(styles)
  return result
end

-- }}}

--------------------------------------------------------------------------------
-- {{{ Functions assisting the implementation, part 2
-- These are lower-level in nature and just do one thing with the argument(s)
-- they are given.
--  * xxx
--  * xxx
--  * xxx
--  * xxx
--------------------------------------------------------------------------------

-- Return: ok, error_details
lbt.fn.impl.template_details_are_valid = function (td)
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
  elseif td.arguments and type(td.arguments) ~= 'table' then
    return false, F('arguments is not a table')
  elseif td.styles and type(td.styles) ~= 'table' then
    return false, F('styles is not a table')
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
lbt.fn.impl.template_arguments_specification = function (arguments)
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

-- Convert { Q = { vspace = '12pt', color = 'blue' }, MC = { alphabet = 'roman' }}
-- to { 'Q.vspace' = '12pt', 'Q.color' = 'blue', 'MC.alphabet' = 'roman'}
--
-- In other words, flatten the dictionary and preseve the prefix.
--
-- Return type: pl.Map
--
-- Return true, result  or  false, errormsg
--
-- TODO implement and test error checking
--
-- NOTE This is replaced with template_normalise_default_options below.
--      Delete this.
lbt.fn.impl.template_styles_specification = function (styles)
  local result = pl.Map()
  for k1,map in pairs(styles) do
    for k2,v in pairs(map) do
      local style_key = F('%s.%s', k1, k2)
      local style_value = v
      result[style_key] = style_value
    end
  end
  return true, result
end

-- Input x is a list of strings, each of which is like
--   'Q.color = blue, Q.vsp = 10pt'
-- Output is a map { 'Q.color' = 'blue', Q.vsp = '10pt', ... }
-- Return  true, output   or   false, error string
lbt.fn.impl.template_normalise_default_options = function (x)
  local result = pl.Map()
  for s in pl.List(x):iter() do
    if type(s) ~= 'string' then
      lbt.err.E581_invalid_default_option_value(s)
    end
    local options = lbt.parser.parse_dictionary(s)
    if options then
      result:update(options)
    else
      return false, s
    end
  end
  return true, result
end

lbt.fn.impl.latex_message_token_not_resolved = function (token)
  return F([[{\color{red}\bfseries Token \verb|%s| not resolved} \par]], token)
end

lbt.fn.impl.latex_message_token_raised_error = function (token, err)
  return F([[{\color{red}\bfseries Token \verb|%s| raised error: \emph{%s}} \par]], token, err)
end

lbt.fn.impl.assign_register = function (args)
  if #args ~= 3 then
    lbt.err.E318_invalid_register_assignment_nargs(args)
  end
  local regname, ttl, defn = table.unpack(args)
  local mathmode = false
  if defn:startswith('$') and defn:endswith('$') then
    mathmode = true
    defn = defn:sub(2,-2)
  end
  local value = lbt.fn.impl.expand_register_references(defn, mathmode)
  local record = { name     = regname,
                   exp      = lbt.fn.impl.current_command_count() + ttl,
                   mathmode = mathmode,
                   value    = value }
  lbt.fn.impl.register_store(record)
end

-- str: the string we are expanding (looking for ◊xyz and replacing)
-- math_context: boolean that helps us decide whether to include \ensuremath
lbt.fn.impl.expand_register_references = function (str, math_context)
  local pattern = "◊%a[%a%d]*"
  local result = str:gsub(pattern, function (ref)
    local name = ref:sub(4)    -- skip the lozenge (bytes 1-3)
    local status, value, mathmode = lbt.fn.impl.register_value(name)
    if status == 'nonexistent' then
      -- This register never existed; don't change anything.
      return ref
    elseif status == 'stale' then
      -- This register has expired; don't change anything.
      -- TODO Consider logging.
      return ref
    elseif status == 'ok' then
      -- We have a live one.
      -- If _this_ register is mathmode and we are _not_ in a mathematical
      -- context, then \ensuremath is needed.
      if mathmode and not math_context then
        return F([[\ensuremath{%s}]], value)
      else
        return value
      end
    else
      lbt.err.E001_internal_logic_error('register_value return error')
    end
  end)
  return result
end

lbt.fn.impl.current_command_count = function ()
  local command_count = lbt.var.command_count
  if command_count == nil then
    lbt.err.E001_internal_logic_error('current command_count not set')
  end
  return command_count
end

lbt.fn.impl.inc_command_count = function ()
  local command_count = lbt.var.command_count
  if command_count == nil then
    lbt.err.E001_internal_logic_error('current command_count not set')
  end
  lbt.var.command_count = command_count + 1
end

lbt.fn.impl.register_store = function (record)
  -- TODO check whether this name is already assigned and not expired
  lbt.var.registers[record.name] = record
end

-- Return status, value, mathmode
-- status: nonexistent | stale | ok
lbt.fn.impl.register_value = function (name)
  local r = lbt.var.registers
  local re = lbt.var.registers[name]
  if re == nil then
    return 'nonexistent', nil
  elseif lbt.fn.impl.current_command_count() > re.exp then
    return 'stale', nil
  else
    return 'ok', re.value, re.mathmode
  end
end

lbt.fn.impl.sources_list_compact_representation = function (sources)
  local name = function (td) return td.name end
  return sources:map(name):join(', ')
end

-- }}}
