--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

local auth = {}  -- namespace for functions to do with author content
local lfc = {}   -- namespace for functions to do with latex_for_command
local reg = {}   -- namespace for functions to do with registers

local __expansion_files_cleared__ = false

local F = string.format

lbt.fn.test = {} -- namespace in which certain private functions are shared
                 -- for testing purposes


-- {{{ (lbt.fn) settings -------------------------------------------------------

lbt.fn.apply_lbt_settings = function (dict)
  dict = pl.Map(dict)
  for k, v in dict:iter() do
    local errmsg = lbt.system.settings:apply(k, v)
    if errmsg then
      -- TODO: specific error function
      local msg = F("Unable to apply lbt setting '%s' -> '%s': details below\n  * %s", k, v, errmsg)
      lbt.err.E002_general(msg)
    end
  end
end

-- }}}

-- {{{ (lbt.fn) test mode

lbt.fn.lbt_test_mode = function(x)
  if x == nil then
    return lbt.system.test_mode
  elseif x == true or x == false then
    lbt.system.test_mode = x
  else
    lbt.err.E002_general("Invalid value for lbt.fn.lbt_test_mode(): '%s'", x)
  end
end

-- }}}

-- {{{ (lbt.fn) options --------------------------------------------------------

-- Return true if operation succeeded; false otherwise.
lbt.fn.options_push = function (text)
  local dict = lbt.parser.parse_dictionary(text)
  if dict then
    local ctx = lbt.fn.get_current_expansion_context()
    ctx:opargs_local_push_dictionary(dict)
    return true
  end
  return false
end

-- Return true if operation succeeded; false otherwise.
-- Currently there is no situation that causes a return value of false.
lbt.fn.options_pop = function (text)
  local keys = lbt.util.comma_split(text)
  local ctx = lbt.fn.get_current_expansion_context()
  ctx:opargs_local_pop_keys(keys)
  return true
end

-- }}}

-- {{{ (lbt.fn) expansion ID, expansion content, command count -----------------

lbt.fn.expansion_in_progress = function (x)
  if x then
    lbt.system.expansion_in_progress = x
  end
  return lbt.system.expansion_in_progress
end

lbt.fn.current_expansion_id = function ()
  if lbt.fn.expansion_in_progress() then
    return lbt.system.expansion_id
  else
    return nil
  end
end

lbt.fn.next_expansion_id = function ()
  lbt.system.expansion_id = lbt.system.expansion_id + 1
  return lbt.system.expansion_id
end

lbt.fn.set_current_expansion_context = function(ctx)
  assert(ctx.type == 'ExpansionContext')
  local eid = lbt.fn.current_expansion_id()
  if eid == nil then
    lbt.err.E001_internal_logic_error('eid is nil and that should not happen')
  else
    lbt.system.expansion_contexts[eid] = ctx
    lbt.const.expansion_context = ctx
  end
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
    return lbt.fn.ExpansionContext.skeleton_expansion_context()
  end
  local ctx = lbt.system.expansion_contexts[eid]
  if ctx == nil then
    lbt.err.E002_general('lbt.fn.get_expansion_context_by_eid(eid) failed: eid = %s', eid)
  end
  return ctx
end

lbt.fn.current_command_count = function ()
  local command_count = lbt.var.command_count
  if command_count == nil then
    lbt.err.E001_internal_logic_error('current command_count not set')
  end
  return command_count
end

lbt.fn.inc_command_count = function ()
  local command_count = lbt.var.command_count
  if command_count == nil then
    lbt.err.E001_internal_logic_error('current command_count not set')
  end
  lbt.var.command_count = command_count + 1
end

-- }}}

-- {{{ (lbt.fn) Author content clear and append (low level) --------------------
--  * author_content_clear      (reset lbt.const and lbt.var data)
--  * author_content_append     (append line to lbt.const.author_content)

lbt.fn.author_content_clear = function()
  lbt.log(4, "lbt.fn.author_content_clear()")
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.fn.author_content_append = function(line)
  lbt.const.author_content:append(line)
end
-- }}}

-- {{{ (lbt.fn and auth) Author content processing (high level) ----------------
--
--  * parsed_content_from_content_lines(lines)
--     - looks at pragmas to see whether we should ignore this content
--     - forms an internal representation of the raw author's content
--     - uses lbt.parser, based on LPEG, to parse the content
--
--  * latex_expansion_of_parsed_content(pc)
--     - generate Latex for the entire author content
--     - this calls the expand(pc) method of the document template
--       - that will almost certainly call latex_for_commands, which calls
--         latex_for_command repeatedly, which creates one LatexForCommand class
--         for a single command
--------------------------------------------------------------------------------


lbt.fn.parsed_content_from_content_lines = function(content_lines)
  -- The content lines are in a list. For lpeg parsing, we want the content as
  -- a single string. But there could be pragmas in there like !DRAFT, and it
  -- is better to extract them now that we have separate lines. Hence we call
  -- a function to do this for us. This function handles » line continuations
  -- as well. It also removes comments lines. This is a pre-parsing stage.
  local pragmas, content = auth.pragmas_and_content(content_lines)
  -- Detect ignore and act accordingly.
  if pragmas.IGNORE then
    return { pragmas = pragmas }
  end
  -- Detect debug and act accordingly.
  if pragmas.DEBUG then
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
    ;   lbt.log('parse', 'Content parsed with lbt.parser.parsed_content_0. Result:')
    ;   lbt.log('parse', pl.pretty.write(x.pc0))
    return lbt.fn.ParsedContent.new(x.pc0, pragmas)
  else
    lbt.err.E110_unable_to_parse_content(content, x.maxposition)
  end
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
-- With everything set up, we can call t.init() and t.expand(pc).
--
-- We return a list of Latex strings, ready to be printed into the document at
-- compile time.
--
lbt.fn.latex_expansion_of_parsed_content = function (pc)
  local template = pc:template_object_or_error()
  local sources = auth.consolidated_sources(pc, template)
  local ctx = lbt.fn.ExpansionContext.new {
    pc = pc,
    template = template.name,
    sources = sources,
    pragmas = pc.pragmas
  }
  lbt.fn.set_current_expansion_context(ctx)
  -- Call init() on all sources to allow for counters, Latex commands, etc.
  local sources_rev = sources:clone(); sources_rev:reverse()
  for tn in sources_rev:iter() do
    local T = lbt.fn.Template.object_by_name(tn)
    if type(T.init) == 'function' then T.init() end
  end
  -- And...go!
  ;   lbt.log(4, 'About to latex-expand template <%s>', pc:template_name())
  local expander = template.expand or lbt.api.default_template_expander()
  local result = expander(pc)
  ;   lbt.log(4, ' ~> result has %d bytes', #result)
  lbt.fn.unset_current_expansion_context()
  return result
end

-- Extract pragmas from the lines into a table.
-- Return a table of pragmas (draft, debug, ignore) and a consolidated string of
-- the actual content, with » line continations taken care of.
auth.pragmas_and_content = function(input_lines)
  local pragmas = lbt.core.default_pragmas()
  local lines   = pl.List()
  for line in input_lines:iter() do
    local p = line:match("!(%u+)%s*$")
    if p then
      auth.update_pragma_set(pragmas, p)
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

-- consolidated_sources(pc,t)
--
-- A template itself has sources, starting with itself. For example, Exam might
-- rely on Questions and Figures. A specific expansion optionally has extra
-- sources defined in @META.SOURCES. The specific ones take precedence.
--
-- It is imperative that lbt.Basic appear somewhere, without having to be named
-- by the user. It might as well appear at the end, so we add it. We include
-- lbt.Math as well, because why not?
--
-- Return: a List of source template _names_ in the order they should be referenced.
-- Client code will use `Template.object_by_name(name)` to access the actual template.
--
auth.consolidated_sources = function (pc, template)
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
  local append_if_necessary = function(template_name)
    local sources = result:filter(function(x) return x == template_name end)
    if sources:len() == 0 then
      local _ = lbt.fn.Template.object_by_name(template_name)
      result:append(template_name)
    end
  end
  append_if_necessary('lbt.Basic')
  append_if_necessary('lbt.Math')
  return result
end

auth.update_pragma_set = function(pragmas, setting)
  local p = setting
  if     p == 'DRAFT'    then pragmas.DRAFT  = true
  elseif p == 'NODRAFT'  then pragmas.DRAFT  = false
  elseif p == 'SKIP'     then pragmas.SKIP   = true
  elseif p == 'NOSKIP'   then pragmas.SKIP   = false
  elseif p == 'IGNORE'   then pragmas.IGNORE = true
  elseif p == 'NOIGNORE' then pragmas.IGNORE = false
  elseif p == 'DEBUG'    then pragmas.DEBUG  = true
  elseif p == 'NODEBUG'  then pragmas.DEBUG  = false
  else
    lbt.err.E102_invalid_pragma(p)
  end
end

-- }}}

-- {{{ (lbt.fn and lfc) latex_for_command(s) -----------------------------------

-- latex_for_commands    -- turn a list of parsed commands into Latex
--
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
-- rather than halt the processing. (Unless the setting HaltOnWarning is in
-- effect.)
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
      local msg = lfc.latex_message_opcode_not_resolved(opcode)
      buffer:append(msg)
      lfc.halt_on_warning { opcode_unresolved = opcode }
    elseif status == 'error' then
      local err = latex
      local msg = lfc.latex_message_opcode_raised_error(opcode, err)
      buffer:append(msg)
      lfc.halt_on_warning { opcode_error = err, opcode = opcode }
    elseif status == 'noop' then
      -- do nothing
    elseif status == 'stop-processing' then
      goto early_exit
    end
  end
  ::early_exit::
  return buffer
end

-- latex_for_command   -- turn a single parsed command into Latex
--
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
  local opcode = parsed_command[1]
  local posargs = parsed_command.a
  lfc.debug_log_parsed_command(parsed_command)
  if opcode == 'STO' then
    return lfc.handle_STO_command(posargs)
  elseif opcode == 'CTRL' then
    return lfc.handle_CTRL_command(posargs)
  else
    local L = lbt.fn.LatexForCommand.new(parsed_command, reg.expand_register_references)
    local status, latex = L:latex()
    if status == 'ok' then lfc.prepend_debug_info(latex, opcode) end
    lfc.debug_log_latex(status, latex)
    return status, latex
  end
end

function lfc.handle_STO_command(posargs)
  reg.assign_register(posargs)
  return 'sto'
end

function lfc.handle_CTRL_command(posargs)
  if posargs[1] == 'stop' then
    return 'stop-processing'
  elseif posargs[1] == 'options' then
    if lbt.fn.options_push(posargs[2]) == false then
      lbt.err.E002_general("(CTRL options) failed with input '%s'", posargs[2])
    end
    return 'noop'
  elseif posargs[1] == 'options-pop' or posargs[1] == 'options pop' then
    if lbt.fn.options_pop(posargs[2]) == false then
      lbt.err.E002_general("(CTRL options-pop) failed with input '%s'", posargs[2])
    end
    return 'noop'
  elseif posargs[1] == 'eid' then
    I('eid', lbt.fn.current_expansion_id())
    lbt.debuglog('Current expansion ID: %d', lbt.fn.current_expansion_id())
    return 'noop'
  elseif posargs[1] == 'microdebug' then
    if posargs[2] == 'on' or posargs[2] == 'off' then
      lbt.fn.microdebug(posargs[2])
    else
      lbt.err.E002_general("Invalid argument for CTRL microdebug: '%s'", posargs[2])
    end
    return 'noop'
  else
    lbt.err.E938_unknown_CTRL_directive(posargs)
  end
end

lfc.latex_message_opcode_not_resolved = function (opcode)
  return F([[\lbtWarning{Opcode \Verb|%s| not resolved} \par]], opcode)
end

lfc.latex_message_opcode_raised_error = function (opcode, err)
  return F([[\lbtWarning{Opcode \Verb|%s| raised error: \emph{%s}} \par]], opcode, err)
end

lfc.halt_on_warning = function(args)
  if not lbt.setting('HaltOnWarning') then return end
  if args.opcode_unresolved then
    lbt.err.E002_general("Opcode not resolved: '%s'", args.opcode_unresolved)
  elseif args.opcode_error then
    lbt.err.E002_general("Opcode '%s' raised error: %s", args.opcode, args.opcode_error)
  end
end

-- `latex` is a list of strings.
-- We insert a \lbtDebugLog{(TexExp 108:23) VSPACE} before the latex.
-- (Only if this expansion has the DEBUG pragma set.)
lfc.prepend_debug_info = function(latex, opcode)
  if lfc.debug_this_expansion() then
    local eid = lbt.fn.current_expansion_id()
    local count = lbt.fn.current_command_count()
    local debug_info = F([[\lbtDebugLog{(TexExp %d:%d) %s}%%]], eid, count, opcode)
    latex:insert(2, debug_info)  -- into position 2 because index 1 is the comment with opcode
  end
end

local row_of_pluses = '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
local row_of_dashes = '----------------------------------------------------------------------'
lfc.debug_log_parsed_command = function(pc)
  if lfc.debug_this_expansion() then
    local eid = lbt.fn.current_expansion_id()
    local count = lbt.fn.current_command_count()
    lbt.debuglog(row_of_pluses)
    lbt.debuglog('(%d:%d) %s', eid, count, pc[1])
  end
end

lfc.debug_log_latex = function(status, latex)
  if lfc.debug_this_expansion() then
    lbt.debuglog(row_of_dashes)
    if status == 'ok' then
      lbt.debuglograw(latex:concat('\n'))
    else
      lbt.debuglog(">> status = '%s'", status)
    end
    lbt.debuglog(row_of_dashes)
  end
end

-- Predicate.
-- We debug "this expansion" if the DEBUG pragma or the DebugAllExpansions setting is active.
lfc.debug_this_expansion = function()
  local debug_pragma = lbt.fn.get_current_expansion_context().pragmas.DEBUG
  return debug_pragma or lbt.setting('DebugAllExpansions')
end

-- }}}

-- {{{ (lbt.fn) Debugging and debug log file -----------------------------------

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

lbt.fn.clear_expansion_files = function ()
  if lbt.setting('ClearExpansionFiles') and not __expansion_files_cleared__ then
    pcall(function()
      pl.dir.rmtree('./lbt-expansions')
    end)
    __expansion_files_cleared__ = true
  end
end

lbt.fn.write_expansion_file = function (eid, latex)
  if lbt.setting('WriteExpansionFiles') then
    pl.dir.makepath('lbt-expansions')
    local filename = F('lbt-expansions/%d.tex', eid)
    local content = nil
    if type(latex) == 'string' then
      content = latex
    elseif type(latex) == 'table' then
      content = latex:concat('\n')
    end
    pl.file.write(filename, content)
  end
end

-- read (x is nil) or write (x is 'on' or 'off) lbt.system.microdebug.
lbt.fn.microdebug = function(x)
  if x == nil then
    return lbt.system.microdebug
  elseif x == 'on' then
    lbt.system.microdebug = true
  elseif x == 'off' then
    lbt.system.microdebug = false
  end
end

-- }}}

-- {{{ (lbt.fn) Functions concerning macros ------------------------------------

-- Input: \myvec=lbt.Math:vector
-- Output:  myvec,       lbt.Math,      vector
--         (latex macro, template name, function name)
--             lm           tn             fn
-- Error: if the text does not follow the correct format
-- XXX: this function is on the way out
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

-- Input: Math:vector
-- Output:  lbt.Math,      vector
--         (template name, function name)
--             tn             fn
-- Error: if the text does not follow the correct format
-- XXX: this function should be in an impl-style namespace
lbt.fn.parse_macro_define_argument2 = function (text)
  local ERR = lbt.err.E109_invalid_macro_define_spec
  local tn, fn = text:match('^([%w.]+):(%w+)')
  if not (tn and fn) then
    ERR(text)
  end
  if not tn:match('^%a') then
    ERR(text)
  end
  return tn, fn
end

lbt.fn.define_latex_macro = function (latexmacro, target)
  -- lm = latex macro (name)    tn = template name    fn = function name
  local lm = latexmacro
  local tn, fn = lbt.fn.parse_macro_define_argument2(target)
  lbt.fn.define_latex_macro_1(lm, tn, fn)
end

-- XXX: put in an impl-style namespace
lbt.fn.define_latex_macro_1 = function (macroname, templatename, functionname)
  local lm = macroname      -- Vijk
  local tn = templatename   -- lbt.Math
  local fn = functionname   -- vectorijk
  local t = lbt.fn.Template.object_by_name_or_nil(tn)
  if t == nil then
    lbt.err.E158_macro_define_error("Template doesn't exist: %s", tn)
  elseif t.macros == nil then
    lbt.err.E158_macro_define_error("Template defines no macros: %s", tn)
  elseif t.macros[fn] == nil then
    lbt.err.E158_macro_define_error("Template %s has no macro function %s", tn, fn)
  elseif type(t.macros[fn]) ~= 'function' then
    lbt.err.E158_macro_define_error(
      "Template %s has macro 'function' %s that's not actually a function", tn, fn)
  else
    local details = F([=[template = '%s', macro = '%s', eid = lbt.fn.current_expansion_id(), arg = [[\unexpanded{#1}]] ]=], tn, fn)
    local latex_cmd = F([[\newcommand{\%s}[1]{\directlua{lbt.api.macro_run { %s } }} ]],
                        lm, details)
    tex.print(latex_cmd)
    lbt.log(3, [[Defined Latex macro \%s to %s.%s]], lm, tn, fn)
    lbt.log(3, ' ~> %s', latex_cmd)
  end
end

-- }}}

-- {{{ (lbt.fn) expand_directory -----------------------------------------------

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

-- }}}

-- {{{ (reg) Functions to do with register expansion ---------------------------

function reg.assign_register(args)
  if #args ~= 3 then
    lbt.err.E318_invalid_register_assignment_nargs(args)
  end
  local regname, ttl, defn = table.unpack(args)
  local mathmode = false
  if defn:startswith('$') and defn:endswith('$') then
    mathmode = true
    defn = defn:sub(2,-2)
  end
  local value = reg.expand_register_references(defn, mathmode)
  local record = { name     = regname,
                   exp      = lbt.fn.current_command_count() + ttl,
                   mathmode = mathmode,
                   value    = value }
  reg.register_store(record)
end

-- str: the string we are expanding (looking for ◊xyz and replacing)
-- math_context: boolean that helps us decide whether to include \ensuremath
function reg.expand_register_references(str, math_context)
  local pattern = "◊%a[%a%d]*"
  local result = str:gsub(pattern, function (ref)
    local name = ref:sub(4)    -- skip the lozenge (bytes 1-3)
    local status, value, mathmode = reg.register_value(name)
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
  return result:gsub('◊◊', '◊')
end

-- Return status, value, mathmode
-- status: nonexistent | stale | ok
function reg.register_value(name)
  local re = lbt.var.registers[name]
  if re == nil then
    return 'nonexistent', nil
  elseif lbt.fn.current_command_count() > re.exp then
    return 'stale', nil
  else
    return 'ok', re.value, re.mathmode
  end
end

function reg.register_store(record)
  -- TODO: check whether this name is already assigned and not expired
  lbt.var.registers[record.name] = record
end

-- }}}

-- {{{ (lbt.fn.test) exposure to some private functions for testing ------------

lbt.fn.test.consolidated_sources = auth.consolidated_sources
lbt.fn.test.pragmas_and_content = auth.pragmas_and_content

-- }}}
