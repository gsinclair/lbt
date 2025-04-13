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
  local sources = self:meta().SOURCES or ''
  if type(sources) == 'string' then
    return lbt.util.comma_split(sources)
  else
    lbt.err.E002_general('Trying to read template SOURCES and didn\'t get a string')
    return sources
  end
end

-- Inside META you can set, for example
--   OPTIONS   vector.format = tilde, QQ.prespace = 18pt
-- Here we grab that content, parse it, and return it as a dictionary.
-- Notes:
--  * if the user wrote ".d vector.format = tilde, QQ.prespace = 18pt"
--    then it is already parsed as a dictionary, so we return that
--  * if the user has set STYLES, that is old-fashioned and we exit
--    fast so they can fix it
--  * if we try to parse a dictionary and fail, we quit with error
function ParsedContent:local_options()
  if self:meta().STYLES then
    IX('Old-fashioned STYLES is set. Use OPTIONS instead', self:meta().STYLES)
  end
  local options = self:meta().OPTIONS
  if type(options) == 'table' then
    return options
  elseif type(options) == 'string' then
    local text = options
    options = lbt.parser.parse_dictionary(text)
    return options or lbt.err.E946_invalid_option_dictionary_narrow(text)
  elseif options == nil then
    return pl.Map()
  else
    lbt.err.E001_internal_logic_error('OPTIONS not a string or table')
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
--   if o:_has_local_key('nopar') then ... end            -- true/false
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
local _err_     = function(x) lbt.err.E190_invalid_OptionLookup(x) end

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
  o.set_opcode_and_options   = OptionLookup.set_opcode_and_options
  o.unset_opcode_and_options = OptionLookup.unset_opcode_and_options
  o._lookup                  = OptionLookup._lookup
  o._has_local_key           = OptionLookup._has_local_key
  o._set_local               = OptionLookup._set_local
  o._has_key                 = OptionLookup._has_key
  o._safe_index              = OptionLookup._safe_index
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
  if string.find(key, '%.') then
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
  v = rawget(ol, _narrow_)[qk]
  if v then return v end
  -- 2. document-wide
  v = rawget(ol, _wide_)[qk]
  if v then return v end
  -- 3. template defaults
  -- NOTE: the next line originally had reverse() in it. I don't think it belongs, but am not 100% sure.
  -- NOTE: I now see that it does belong. If a template T lists sources as (say) A, B, C, then the 'sources' list will be T, A, B, C, Basic. Now say they want an option QQ.color, which is provided in both A and C. We want to be able to override options, so we have to go from the right end of the list. But I need to think about Basic. It could be that looking up options among our sources is more complicated than I thought. (And what about nested dependencies? I haven't really thought about that.) Perhaps a stack of tables like { desc = 'docwide', templates = {...} } is necessary; then the lookup just makes its way through the stack.
  for t in pl.List(rawget(ol, _sources_)):iter() do
    v = t.default_options[qk]
    if v ~= nil then return v end
  end
  -- 4. Nothing found
  return nil
end

-- Doing an option lookup is complex.
--  * First of all, the key is probably a simple one ('color') and needs to be
--    qualified ('QQ.color').
--  * Then, it might be set as an opcode-local option.
--    However, it is possible to resolve an option without even having an opcode.
--    A template could be rendering a title page, for example. It hasn't even
--    got to BODY yet.
--  * Otherwise, it might be in the cache, from a previous access.
--  * Otherwise, it might be a document-narrow option.
--  * Otherwise, it might be a document-wide option.
--  * Otherwise, it might be a default in a template.
-- If the key cannot be found anywhere, we return nil. A missing option should
-- be an error, but we leave that up to the caller because we want to provide
-- different errors depending on whether the lookup was for a command or for
-- a macro.
function OptionLookup:_lookup(key)
  lbt.assert_string(1, key) -- TODO: make an lbt.err for this
  local qk = qualified_key(self, key)
  local v
  -- 1. Local option.
  if rawget(self, _local_) ~= nil then
    v = rawget(self, _local_)[key]
    if v ~= nil then return v end
    -- 1b. Local 'nopar' (say) as a shortcut for 'par = false'. We should do some
    --     checking on this ('nobeer' should succeed only if 'beer' is a valid option).
    --     How this works: author writes 'TEXT .o nopar :: ...'. Latex expansion calls
    --     ol['par']. Because 'nopar' is set locally, ol['par'] has value false.
    v = rawget(self, _local_)['no'..key]
    if v == true then return false end
  end
  -- 2. Cache.
  v = rawget(self, _cache_)[qk]
  if v ~= nil then return v end
  -- 3. Other.
  v = multi_level_lookup(self, qk)
  if v ~= nil then
    rawget(self, _cache_)[qk] = v
    return v
  end
  -- 4. No match.
  return nil
end

-- On occasion it might be necessary to look up a local key that doesn't exist.
-- That would produce an error. So we provide _has_local_key to avoid errors.
-- Example of use: _any_ command can have a 'starred' option, but not all will.
-- So we can call o:_has_local_key('starred') to do the check without risking an
-- error.
function OptionLookup:_has_local_key(key)
  return rawget(self, _local_) ~= nil and rawget(self, _local_)[key] ~= nil
end

-- There are cases where the implementation of a command has to change a
-- local option key. For example:
--   TEXT* It was a dark and stormy night.
-- TEXT by default has 'par = true', but because of the star, we want to
-- change that to 'par = false'. It needs to be done this way, because the
-- paragraph handling (appending \par to the Latex output) is done outside
-- the TEXT implementation.
--
-- There is probably (and hopefully) no other use case for this.
function OptionLookup:_set_local(key, value)
  local l = rawget(self, _local_)
  l[key] = value
end

-- Same spirit as _has_local_key, but not limited to local keys. Also, must provide
-- the 'base' and the key, so that a qualified key can be constructed. For example,
-- _has_key('TEXT', 'starred').
function OptionLookup:_has_key(base, key)
  local qk = base .. '.' .. key   -- qualified key
  return self:_lookup(qk) ~= nil
end

-- ol.froboz                  --> error
-- ol:_safe_index('froboz')   --> nil
function OptionLookup:_safe_index(key)
  local value = self:_lookup(key)
  if value == nil then return nil end
  return value
end

-- ol['QQ.color'] either returns the value or raises an error.
-- If the value is the string 'nil' then we return nil instead.
-- (Just this one special case.) Note that 'true' and 'false' are
-- handled by the lpeg, but 'nil' cannot be, because in that case
-- the key would not be added to the table.
OptionLookup.__index = function(self, key)
  lbt.assert_string(2, key) -- TODO: make an lbt.err for this
  local v = self:_lookup(key)
  if v == nil then
    lbt.err.E192_option_lookup_failed(rawget(self, _opcode_), key)
  elseif v == 'nil' then
    return nil
  else
    return v
  end
end

-- A function call is just a convenient alternative for a table reference.
-- Even more convenient, because you can resolve more than one option at a time.
--   o('Q.prespace Q.color')   --> '30pt', 'blue'
OptionLookup.__call = function(self, keys_string)
  local keys = lbt.util.space_split(keys_string)
  local values = keys:map(function(k) return self[k] end)
  return table.unpack(values)
end

OptionLookup.__tostring = function(self)
  local x = pl.List()
  local add = function(fmt, ...)
    x:append(F(fmt, ...))
  end
  local pretty = function(x)
    if x == nil then
      return 'nil'
    elseif pl.tablex.size(x) == 0 then
      return '{}'
    else
      local dump = pl.pretty.write(x)
      return dump:gsub('\n', '\n  '):gsub('^', '  ')
    end
  end
  add('OptionLookup:')
  add('  opcode: %s', rawget(self, _opcode_))
  add('  local options: %s', pretty(rawget(self, _local_)))
  add('  cache: %s', pretty(rawget(self, _cache_)))
  add('  doc-narrow: %s', pretty(rawget(self, _narrow_)))
  add('  doc-wide: %s', pretty(rawget(self, _wide_)))
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
    -- NOTE: the line below fails because ParsedContent.new checks that argument 1 is a table.
    -- return ParsedContent.new(nil, pragmas)
    return { pragmas = pragmas }
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

-- 
lbt.fn.set_current_opcode_resolver = function(ocr)
  lbt.const.opcode_resolver = ocr
end

lbt.fn.set_current_option_lookup_object = function(ol)
  lbt.const.option_lookup = ol
end

lbt.fn.unset_current_opcode_resolver = function(ocr)
  lbt.const.opcode_resolver = nil
end

lbt.fn.unset_current_option_lookup_object = function(ol)
  lbt.const.option_lookup = nil
end
-- 
lbt.fn.get_current_opcode_resolver = function()
  local ocr = lbt.const.opcode_resolver
  if ocr == nil then
    lbt.err.E001_internal_logic_error('lbt.const.opcode_resolver not available')
  end
  return ocr
end

lbt.fn.get_current_option_lookup_object = function()
  local ol = lbt.const.option_lookup
  if ol == nil then
    lbt.err.E001_internal_logic_error('lbt.const.option_lookup not available')
  end
  return ol
end

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
-- QQ needs to be able to access 'o.color' and 'o.prespace' easily. Thus we call
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
    document_wide = lbt.system.document_wide_options,
    document_narrow = pc:local_options(),
    sources = sources,
  }
  -- Save the option lookup for access by macros like Math.vector and commands like DB or STO.
  lbt.fn.set_current_opcode_resolver(ocr)
  lbt.fn.set_current_option_lookup_object(ol)
  -- Allow the template to initialise counters, etc.
  if type(t.init) == 'function' then t.init() end
  -- And...go!
  lbt.log(4, 'About to latex-expand template <%s>', pc:template_name())
  local result = t.expand(pc, ocr, ol)
  lbt.log(4, ' ~> result has %d bytes', #result)
  -- Expansion has finished, so we unset the ocr and ol
  lbt.fn.unset_current_opcode_resolver()
  lbt.fn.unset_current_option_lookup_object()
  return result
end


-- This is called (directly or indirectly) within a template's 'expand' function.
-- It would usually be indirect. For example:
--   lbt.WS0 (template)
--     expand  (function)
--       lbt.util.latex_expand_content_list('BODY', pc, ocr, ol)
--         lbt.fn.latex_for_commands
--
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
lbt.fn.latex_for_commands = function (commands, ocr, ol)
  local buffer = pl.List()
  for command in commands:iter() do
    local status, latex = lbt.fn.latex_for_command(command, ocr, ol)
    if status == 'ok' then
      buffer:extend(latex)
    elseif status == 'notfound' then
      local msg = lbt.fn.impl.latex_message_opcode_not_resolved(command[1])
      buffer:append(msg)
    elseif status == 'error' then
      local err = latex
      local msg = lbt.fn.impl.latex_message_opcode_raised_error(command[1], err)
      buffer:append(msg)
    elseif status == 'noop' then
      -- do nothing
    elseif status == 'stop-processing' then
      goto early_exit
    end
  end
  ::early_exit::
  return buffer
end

-- Take a single command of parsed author content like
--   { 'ITEMIZE', o = { float = true}, k = {}, a = {'One', 'Two', 'Three'} }
-- and produce a pl.List of Latex code lines.
--
-- Before sending the arguments to the opcode function, any register references
-- like ◊ABC are expanded. Also, STO is treated specially. And, in the future,
-- CTRL.
--
-- Parameters:
--  * command: parsed author content
--  * ocr:     an opcode resolver that we call to get an opcode function
--  * ol:      an options lookup that we pass to the function
--
-- Return:
--  * 'ok', latex list         [succesful]
--  * 'sto', nil               [STO register allocation]
--  * 'stop-processing', nil   [CTRL stop]
--  * 'noop', nil              [a CTRL directive requiring no output]
--  * 'notfound', nil          [opcode not found among sources]
--  * 'error', details         [error occurred while processing command]
--
-- Side effect:
--  * lbt.var.line_count is increased (unless this is a register allocation)
--  * lbt.var.registers might be updated
lbt.fn.latex_for_command = function (command, ocr, ol)
  local opcode = command[1]
  local args  = command.a
  local nargs = #args
  local opargs = command.o
  local kwargs = command.k
  local cmdstr = F('[%s] %s', opcode, table.concat(args, ' :: '))
  lbt.log(4, 'latex_for_command: opcode = %s', opcode)
  lbt.log(4, 'latex_for_command: opargs = %s', lbt.pp(opargs))
  lbt.log(4, 'latex_for_command: kwargs = %s', lbt.pp(kwargs))
  lbt.log(4, 'latex_for_command: args   = %s', lbt.pp(args))
  lbt.log('emit', '')
  lbt.log('emit', 'Line: %s', cmdstr)

  if opcode == 'DB' and args[2] == 'index' then DEBUGGER() end

  -- 1a. Handle a register allocation. Do not increment command count.
  if opcode == 'STO' then
    lbt.fn.impl.assign_register(args)
    return 'sto', nil
  end
  -- 1b. Handle a CTRL dirctive.
  if opcode == 'CTRL' then
    if args[1] == 'stop' then
      return 'stop-processing', nil
    elseif args[1] == 'eid' then
      I('eid', lbt.fn.current_expansion_id())
      return 'noop', nil
    else
      lbt.err.E938_unknown_CTRL_directive(args)
    end
  end
  -- 2. Search for an opcode function (and argspec) and return if we did not find one.
  --    This must be aware of starred commands. For example, TEXT* needs to be
  --    interpreted as 'TEXT .o starred', whereas 'QQ*' is a function in its own
  --    right.
  local x = lbt.fn.impl.resolve_opcode_function_and_argspec(opcode, ocr, ol)
  ;           -->     { opcode_function = ..., argspec = ... }
  ;           -->  or { opcode_function = ..., argspec = ..., starred = true }
  -- if opcode == 'Q' then DEBUGGER() end
  if x == nil then
    lbt.log('emit', '    --> NOTFOUND')
    lbt.log(2, 'opcode not resolved: %s', opcode)
    return 'notfound', nil
  end
  if x.starred then
    opcode = opcode:sub(1,-2)
    opargs.starred = true
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
  for k, v in kwargs:iter() do
    v = lbt.fn.impl.expand_register_references(v, false)
    kwargs[k] = v
  end
  -- 6. Call the opcode function and return 'error', ... if necessary.
  ;         -- XXX: I want opargs to be resolved at this stage, so that 'nopar = true' becomes 'par = false'.
  ;         --      But this is a challenge.
  ;         -- NOTE: Actually,  think it can happen inside set_opcode_and_options().
  ol:set_opcode_and_options(opcode, opargs)    -- Having to set and unset is a shame, but probably efficient.

  local result = x.opcode_function(nargs, args, ol, kwargs)
  local extras = lbt.fn.impl.extract_from_option_lookup(ol, { 'par', 'prespace', 'postspace' })
  ol:unset_opcode_and_options()
  if type(result) == 'string' then
    result = pl.List({result})
  elseif type(result) == 'table' and type(result.error) == 'string' then
    local errormsg = result.error
    lbt.log('emit', '    --> ERROR: %s', errormsg)
    lbt.log(1, 'Error occurred while processing opcode %s\n    %s', opcode, errormsg)
    return 'error', errormsg
  elseif type(result) == 'table' then
    result = pl.List(result)
  else
    lbt.err.E325_invalid_return_from_template_function(opcode, result)
  end
  -- 7. Do some light processing of the result: apply options par/nopar and
  --    prespace and postspace.
  if extras.par then
    result:append('\\par') -- TODO: replace with general_formatting_wrap ?
  end
  if extras.prespace then
    result:insert(1, F([[\vspace{%s}]], extras.prespace))
  end
  if extras.postspace then
    result:append(F([[\vspace{%s}]], extras.postspace))
  end
  -- 8. We are done. Log the result and return.
  lbt.log('emit', '    --> SUCCESS')
  for line in result:iter() do
    lbt.log('emit', '       |  ' .. line)
  end
  return 'ok', result
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
--
lbt.fn.opcode_resolver = function (sources)
  -- return pl.utils.memoize(
    -- NOTE: 8 Dec 2024 - Experimenting with _not_ memoising the function, because
    --       I am getting erroneous return values where 'starred' is making its way
    --       in, for some reason.
    return function (token)
      -- if token:startswith('MATH') then DEBUGGER() end
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
    end
  -- )
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
  local ok, err_detail, x   -- (needed throughout the function)
  -- (1) Fill some gaps for things that don't have to be filled in.
  td.functions       = td.functions       or {}
  td.arguments       = td.arguments       or {}
  td.default_options = td.default_options or {}
  td.macros          = td.macros          or {}
  -- (2) Check for errors in the spec.
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
  -- (3) Normalise some of the specified values.
  --
  -- Having cleared the hurdles so far and registered the template,
  -- we now act on the argument specification and turn it into
  -- something that can be used at expansion time.
  ok, x = lbt.fn.impl.template_arguments_specification(td.arguments)
  if ok then
    td.arguments = x
  else
    lbt.err.E215_invalid_template_details(td, path, x)
  end
  -- Likewise with default options. They are specified as strings and need to be
  -- turned into a map.
  -- Update Oct 2024: I am supporting a new way of specifying default options,
  -- which this function will need to support.
  ok, x = lbt.fn.impl.template_normalise_default_options(td.default_options)
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
--------------------------------------------------------------------------------

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
lbt.fn.impl.template_normalise_default_options = function (xs)
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

lbt.fn.impl.latex_message_opcode_not_resolved = function (opcode)
  return F([[{\color{lbtError}\bfseries Opcode \verb|%s| not resolved} \par]], opcode)
end

lbt.fn.impl.latex_message_opcode_raised_error = function (opcode, err)
  return F([[{\color{lbtError}\bfseries Opcode \verb|%s| raised error: \emph{%s}} \par]], opcode, err)
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

-- Given an opcode like 'SECTION' and an opcode resolver (ocr), return
--   { opcode_function = ..., argspec = ..., starred = true (perhaps) }
-- If no function exists for the opcode, return nil.
-- (The opcode resolver will try the current template, then any sources, then...)
-- All this is handled by the ocr; we don't implement any smart logic, yet.
--
-- What we _do_ implement is the smarts surrounding starred commands. The opcode
-- TEXT* will result in the same opcode_function as TEXT, but the oparg 'starred'
-- needs to be set. But there are permutations. Consider TEXT*, QQ* and PART*.
--
-- ocr('TEXT*') will return nil because it is not registered as its own command.
-- So we check ocr('TEXT') and get a result. Further, the TEXT function supports
-- the oparg 'starred' (default false, of course). So we now have our function and
-- need to communicate that 'starred = true' needs to be registered in the opargs.
--
-- ocr('QQ*') will return a result because it is implemented directly. So we don't do
-- anything special.
--
-- ocr('PART*') will return nil, and ocr('PART') will return a result. However, the
-- opargs for PART do not include 'starred', so there is in fact no implementation
-- for PART*, and we return nil.
--
-- The code is messy, but I don't really see any choice.
--
lbt.fn.impl.resolve_opcode_function_and_argspec = function (opcode, ocr, ol)
  lbt.debuglog('resolve_opcode_function_and_argspec:')
  lbt.debuglog('  opcode = %s', opcode)
  lbt.debuglog('  ocr    = %s', ocr)
  lbt.debuglog('  ol     = %s', ol)
  local x, base
  x = ocr(opcode)
  if x then
    return x               -- First time's a charm, like SECTION or QQ*
  end
  -- Maybe this is a starred opcode?
  if opcode:endswith('*') then
    base = opcode:sub(1,-2)
    x = ocr(base)
    if x == nil then
      return nil           -- There is no base opcode with potential star, like PQXYZ*
    else
      -- There is potential but we need to check.
      if ol:_has_key(base, 'starred') then
        -- Bingo! We have something like SECTION*
        x.starred = true
        return x
      else
        -- Boo. We have something like PART*, where PART does not allow for a star
        return nil
      end
    end
  else
    -- This is not a starred opcode, like PQXYZ, so we are out of luck.
    return nil
  end
end

-- Input: ol, { 'nopar', 'prespace' }
-- Output: { nopar = false, prespace = '6pt' }
lbt.fn.impl.extract_from_option_lookup = function(ol, keys)
  local result = {}
  for key in pl.List(keys):iter() do
    local value = ol:_safe_index(key)
    result[key] = value
  end
  return result
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
