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
  lbt.const.author_content:append(line)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Processing author content and emitting Latex code
--  * parsed_content(c)        (internal representation of the author's content)
--  * latex_expansion(pc)      (Latex representation based on the parsed content)
--------------------------------------------------------------------------------


lbt.fn.parsed_content_from_content_lines = function(content_lines)
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
    return lbt.fn.ParsedContent.new(x.pc0, pragmas)
  else
    lbt.err.E110_unable_to_parse_content(content, x.maxposition)
  end
end

lbt.fn.set_current_expansion_context = function(ctx)
  assert(ctx.type == 'ExpansionContext')
  local eid = lbt.fn.current_expansion_id()
  lbt.system.expansion_contexts[eid] = ctx
  lbt.const.expansion_context = ctx
end

lbt.fn.unset_current_expansion_context = function()
  lbt.const.expansion_context = nil
end

lbt.fn.get_current_expansion_context = function()
  local ctx = lbt.const.expansion_context
  if ctx == nil then
    lbt.err.E002_general('lbt.fn.get_current_expansion_context() failed')
  end
  return ctx
end

lbt.fn.get_expansion_context_by_eid = function(eid)
  if eid == nil then
    lbt.err.E002_general('Unable to get expansion context: nil expansionID provided')
  end
  local ctx = lbt.system.expansion_contexts[eid]
  if ctx == nil then
    lbt.err.E002_general('lbt.fn.get_expansion_context_by_eid(eid) failed: eid = %s', eid)
  end
  return ctx
end

-- lbt.fn.latex_expansion_of_parsed_content(pc)
--
-- A very important function, turning parsed content into Latex, using the main
-- template and any extra chosen sources to resolve each command.
--
-- We need a template object `template` on which we call t.init() for any
-- initialisation and t.expand(pc) to produce the Latex in line with the
-- template's implementation. (Consider that an Article, Exam and Worksheet
-- template will all produce different-looking documents, without even
-- considering their different contents.)
--
-- We need to know what sources are being used. The template itself will name
-- some, and the document may name more. Thus we have the helper function
-- consolidated_sources(pc, t) to produce a list of template objects in which
-- we can search for command implementations.
--
-- We need an ExpansionContext `ctx` so that 'ITEMIZE' in a document can be
-- resolved into a Lua function (template lbt.Basic -> functions -> ITEMIZE)
-- using the method `ctx.resolve_opcode('ITEMIZE')`. This object will also
-- help to resolve oparg values.
--
-- After creating that object, we save it as a globally-accessible value so
-- that all code actually doing the expansion can access it. (It is too much
-- bother to pass it around everywhere. Also, it's a bit niche and technical,
-- but LBT macros need access to expansion contexts long after the expansion
-- has taken place.) We 'unset' the current expansion context afterwards, but
-- it is still accessible using `()fn.get_expansion_context_by_eid()`.
--
-- With everything set up, we can call t.init() and t.expand(pc, or, ol).
--
-- We return a list of Latex strings, ready to be printed into the document at
-- compile time.
--
lbt.fn.latex_expansion_of_parsed_content = function (pc)
  local template = pc:template_object_or_error()
  local ctx = lbt.fn.ExpansionContext.new {
    pc = pc,
    template = template.name,
    sources = lbt.fn.impl.consolidated_sources(pc, template)
  }
  lbt.fn.set_current_expansion_context(ctx)
  -- Allow the template to initialise counters, etc.
  if type(template.init) == 'function' then template.init() end
  -- And...go!
  lbt.log(4, 'About to latex-expand template <%s>', pc:template_name())
  local result = template.expand(pc)
  lbt.log(4, ' ~> result has %d bytes', #result)
  lbt.fn.unset_current_expansion_context()
  return result
end


-- This is called (directly or indirectly) within a template's 'expand' function.
-- It would usually be indirect. For example:
--   lbt.WS0 (template)
--     expand  (function)
--       lbt.util.latex_expand_content_list('BODY', pc)
--         lbt.fn.latex_for_commands
--
-- Return List of strings, each containing Latex for a line of author content.
-- If a line cannot be evaluated (no function to support a given token) then
-- we insert some bold red information into the Latex so the author can see,
-- rather than halt the processing.
--
-- parsed_commands:
--   List of parsed commands like {'TEXT', o = {}, k = {}, a = {'Hello'}}
--
lbt.fn.latex_for_commands = function (parsed_commands)
  local buffer = pl.List()
  for parsed_command in parsed_commands:iter() do
    local opcode = parsed_command[1]
    local status, latex = lbt.fn.latex_for_command(parsed_command)
    if status == 'ok' then
      buffer:extend(latex)
    elseif status == 'notfound' then
      local msg = lbt.fn.impl.latex_message_opcode_not_resolved(opcode)
      buffer:append(msg)
    elseif status == 'error' then
      local err = latex
      local msg = lbt.fn.impl.latex_message_opcode_raised_error(opcode, err)
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
--
-- Global variable:
--  * `ctx` obtained from lbt.fn.get_current_expansion_context() so that opcodes
--    and opargs can be resolved.
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
lbt.fn.latex_for_command = function (parsed_command)
  local pcmd = parsed_command
  local opcode = pcmd[1]
  local args   = pcmd.a      -- NOTE: many of these locals should be unnecessary now
  local opargs = pcmd.o
  local kwargs = pcmd.k
  local cmdstr = F('[%s] %s', opcode, table.concat(args, ' :: '))
  lbt.log(4, 'latex_for_command: opcode = %s', opcode)
  lbt.log(4, 'latex_for_command: opargs = %s', lbt.pp(opargs))
  lbt.log(4, 'latex_for_command: kwargs = %s', lbt.pp(kwargs))
  lbt.log(4, 'latex_for_command: args   = %s', lbt.pp(args))
  lbt.log('emit', '')
  lbt.log('emit', 'Line: %s', cmdstr)

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
  -- 2. Use the current expansion context to build a Command object for the current
  --    command. (Or get nil if it's an unknown opcode.)
  local ctx = lbt.fn.get_current_expansion_context()
  local cmd = lbt.fn.Command.new(pcmd, ctx)
  if cmd == nil then
    lbt.log('emit', '    --> NOTFOUND')
    lbt.log(2, 'opcode not resolved: %s', opcode)
    return 'notfound', nil
  end
  -- 3. Check that opargs, kwargs and posargs are valid before proceeding.
  local errmsg = cmd:validate_all_arguments()
  if errmsg then
      lbt.log('emit', '    --> ERROR: %s', errmsg)
      lbt.log(1, 'Error attempting to expand opcode:\n    %s', errmsg)
      return 'error', errmsg
  end
  -- 4. We really are processing a command, so we can increase the command_count.
  lbt.fn.impl.inc_command_count()
  -- 5. Expand register references where necessary.
  --    We are not necessarily in mathmode, hence false.
  --    Update the `cmd` object after processing.
  args = args:map(lbt.fn.impl.expand_register_references, false)
  for k, v in kwargs:iter() do
    v = lbt.fn.impl.expand_register_references(v, false)
    kwargs[k] = v
  end
  cmd:update_posargs(args)
  cmd:update_kwargs(kwargs)
  -- 6. Call the opcode function and return 'error', ... if necessary.
  ;         -- XXX: I want opargs to be resolved at this stage, so that 'nopar = true' becomes 'par = false'.
  ;         --      But this is a challenge.
  ;         -- NOTE: Actually,  think it can happen inside set_opcode_and_options().
  local result = cmd:apply_function()
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
  local extras = cmd:oparg_values { 'par', 'prespace', 'postspace' }
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

-- }}}

-- TODO: work out exactly where this should be. Perhaps it's here, perhaps not.
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
  local pragmas = { draft = false, ignore = false, debug = false }
  local lines   = pl.List()
  for line in input_lines:iter() do
    local p = line:match("!(%u+)%s*$")
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
-- Return: a List of source template _names_ in the order they should be referenced.
-- Client code will use `Template.object_by_name(name)` to access the actual template.
--
lbt.fn.impl.consolidated_sources = function (pc, template)
  local src1 = pc:extra_sources()          -- optional specific source names (List)
  local src2 = pl.List(template.sources)   -- source names baked in to the template (List)
  local sources = pl.List();
  do
    sources:extend(src1);
    sources:append(template.name)          -- the template itself has to go in there
    sources:extend(src2)
  end
  local result = pl.List()
  for name in sources:iter() do
    local t = lbt.fn.Template.object_by_name_or_nil(name)
    if t then
      result:append(name)
    else
      lbt.err.E206_cant_form_list_of_sources(name)  -- TODO: look to improve this error message
    end
  end
  local basic_sources = result:filter(function(x) return x == 'lbt.Basic' end)
  if basic_sources:len() == 0 then
    local _ = lbt.fn.Template.object_by_name('lbt.Basic')
    result:append('lbt.Basic')
  end
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
  -- TODO: check whether this name is already assigned and not expired
  lbt.var.registers[record.name] = record
end

-- Return status, value, mathmode
-- status: nonexistent | stale | ok
lbt.fn.impl.register_value = function (name)
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
