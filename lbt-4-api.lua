--
-- We act on the global table `lbt` and populate its subtable `lbt.api`.
--

local F = string.format

-- Reset all global data but leave the following things alone:
--  * builtin templates
--  * draft and debug mode
--
-- Designed to be helpful for testing. Should not be needed elsewhere.
lbt.api.reset_global_data = function ()
  lbt.init.soft_reset_system()
  lbt.init.reset_const_var()
end

-- Each Lua file in the directory is loaded and expected to produce a table
-- that functions as a template description. This table and the path are stored
-- together in the template register, where both can be easily retrieved in
-- future by name. See:
--  * lbt.fn.Template.object_by_name(name)    _or_nil
--  * lbt.fn.Template.path_by_name(name)      _or_nil
lbt.api.load_templates_from_directory = function (dir)
  dir = lbt.fn.expand_directory(dir)
  if not pl.path.isdir(dir) then
    lbt.err.E208_nonexistent_template_dir(dir)
  end
  lbt.log(3, "Adding template directory: %s", dir)
  local paths = pl.dir.getfiles(dir, "*.lua")
  for path in paths:iter() do
    lbt.log(3, " * %s", pl.path.basename(path))
    local ok, x = pcall(dofile, path)
    if ok then
      local template_spec = x
      local template = lbt.fn.Template.new(template_spec, path)
      template:register()
    else
      local err_details = x
      lbt.err.E213_failed_template_load(path, err_details)
    end
  end
  lbt.log(3, "Added template directory <%s>", dir)
  lbt.log('templates', "Added template directory <%s>", dir)
  lbt.fn.Template.names_to_logfile()
end

--------------------------------------------------------------------------------
-- The Latex environment `lbt` calls the following API funtions:
--
--  * author_content_collect, which clears the decks for a new bit of
--    processing and sets up a callback to handle all lines itself (thus
--    avoiding any TeX funny business). Lines are appended to the list
--    `lbt.var.author_content`. This stops when the line `\end{lbt}` is seen.
--
--  * author_content_emit_latex, which parses the author content into an
--    intermediate format, then emits Latex code based on this.
--
--------------------------------------------------------------------------------

-- This is called at the start of an lbt environment. See above and lby.sty.
lbt.api.author_content_collect = function()
  -- Reset constants and variables ready for a new lbt expansion.
  lbt.fn.author_content_clear()
  -- Define function to handle every line in the `lbt` environment.
  local f = function(line)
    if line:strip() == [[\end{lbt}]] then
      luatexbase.remove_from_callback('process_input_buffer', 'process_line')
      return line
    else
      lbt.fn.author_content_append(line)
      return ""
    end
  end
  -- Register that function. It will be unregistered when the environment ends.
  luatexbase.add_to_callback('process_input_buffer', f, 'process_line')
  -- Informative log message.
  lbt.log(3, " ")
  lbt.log(3, "+---------------------------------+")
  lbt.log(3, "| New lbt environment encountered |")
  lbt.log(3, "+---------------------------------+")
  lbt.log(3, "  * expansion ID:   %d", lbt.fn.next_expansion_id())
  lbt.log(3, "  * filename:       %s", status.filename)
  lbt.log(3, "  * line:           %s", status.linenumber)
end

-- This is called at the end of an lbt environment. See above and lby.sty.
-- TODO: Tidy this code up. Move all logging statements elsewhere (new file lbt-0-log.lua?)
lbt.api.author_content_emit_latex = function()
  lbt.fn.expansion_in_progress(true)
  local c  = lbt.const.author_content
  local eid = lbt.fn.current_expansion_id()
  lbt.log(4, "lbt.api.author_content_emit_latex()")
  lbt.log(3, "  * author content: %d lines", #c)
  lbt.log('read', 'Contents of lbt.const.author_content pasted below. eID=%d', eid)
  lbt.log('read', "<<<")
  lbt.log('read', pl.pretty.write(c))
  lbt.log('read', ">>>")
  lbt.log('read', "")
  local pc = lbt.fn.parsed_content_from_content_lines(c)
  if pc.pragmas.IGNORE then
    lbt.log(3, '  * IGNORE pragma detected - no further action for eID %d', eid)
    return
  elseif pc.pragmas.SKIP then
    lbt.log(3, '  * SKIP pragma detected - no further action for eID %d', eid)
    local skipmsg = F([[{\noindent\color{lbtError}\bfseries Explicitly instructed to skip content (eID=%d). Title is `%s`. }]], eid, pc:title())
    tex.print(skipmsg)
    return
  elseif lbt.setting('ExpandOnly') and not lbt.setting('ExpandOnly')[eid] then
    local skipmsg = F([[{\noindent\color{lbtError}\bfseries Skipping content (eID=%d) because of ExpandOnly setting. Title is `%s' }]], eid, pc:title())
    tex.print(skipmsg)
    lbt.log(3, '  * ExpandOnly does not include this eID - no further action for eID %d', eid)
    return
  elseif pc.pragmas.DRAFT == false and lbt.setting('DraftMode') == true then
    local draftskipmsg = F([[{\noindent\color{lbtError}\bfseries Skipping non-draft content (eID=%d). Title is `%s' }]], eid, pc:title())
    tex.print(draftskipmsg)
    lbt.log(3, '  * DRAFT pragma _not_ detected - no further action for eID %d', eid)
    return
  end
  lbt.log('parse', 'Parsed content below. eID=%d', eid)
  lbt.log('parse', lbt.pp(pc))
  lbt.fn.ParsedContent.validate(pc)
  lbt.log(3, '  * template:       %s', pc:template_name())
  local l = lbt.fn.latex_expansion_of_parsed_content(pc)
  local output = lbt.util.normalise_latex_output(l)
  lbt.log(3, '  * latex expansion complete (eid=%d)', eid)
  lbt.util.print_tex_lines(output)
  lbt.fn.clear_expansion_files()
  lbt.fn.write_expansion_file(eid, output)
  lbt.fn.reset_log_channels_if_necessary()
  lbt.fn.expansion_in_progress(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

lbt.api.set_draft_mode = function(_)
  lbt.err.E002_general("Don't use \\lbtDraftModeOn|Off anymore. Use \\lbtSettings{DraftMode = true}")
end

-- Counters are auto-created, so this will always return a value. The initial
-- value will be zero.
-- Normal counters are stored in lbt.var because they are variable and they get
-- cleared at the start of each expansion.
lbt.api.counter_value = function(c)
  lbt.var.counters[c] = lbt.var.counters[c] or 0
  return lbt.var.counters[c]
end

lbt.api.counter_set = function(c, v)
  lbt.var.counters[c] = v
end

lbt.api.counter_reset = function(c)
  lbt.var.counters[c] = 0
end

lbt.api.counter_inc = function(c)
  local v = lbt.api.counter_value(c)
  lbt.api.counter_set(c, v+1)
  return v+1
end

-- Persistent counters are like normal counters, but are stored in lbt.system
-- so they don't get cleared.
lbt.api.persistent_counter_value = function(c)
  lbt.system.persistent_counters[c] = lbt.system.persistent_counters[c] or 0
  return lbt.system.persistent_counters[c]
end

lbt.api.persistent_counter_set = function(c, v)
  lbt.system.persistent_counters[c] = v
end

lbt.api.persistent_counter_reset = function(c)
  lbt.system.persistent_counters[c] = 0
end

lbt.api.persistent_counter_inc = function(c)
  local v = lbt.api.persistent_counter_value(c)
  lbt.api.persistent_counter_set(c, v+1)
  return v+1
end

-- 'data' is state that can be stored by one template function and
-- retrieved by another. A good example is the current heading, so that
-- a context-sensitive header can be created.
lbt.api.data_get = function(key, initval)
  if lbt.var.data[key] == nil then
    lbt.var.data[key] = initval
  end
  return lbt.var.data[key]
end

lbt.api.data_set = function(key, value)
  lbt.var.data[key] = value
end

lbt.api.data_delete = function (key)
  lbt.var.data[key] = nil
end

-- Persistent data is just like normal data but it is not cleared out at
-- the start of every expansion. Good for chapter abbreviations in the
-- lbt.Quiz template.
lbt.api.persistent_data_get = function(key, initval)
  if lbt.system.persistent_data[key] == nil then
    lbt.system.persistent_data[key] = initval
  end
  return lbt.system.persistent_data[key]
end

lbt.api.persistent_data_set = function(key, value)
  lbt.system.persistent_data[key] = value
end

lbt.api.persistent_data_set_keyval = function(text)
  local key, value = pl.utils.splitv(text, '=', 2)
  if key == nil or value == nil then
    lbt.err.E999_lbt_command_failed([[\lbtPersistentDataSet: %s]], text)
  end
  lbt.api.persistent_data_set(key, value)
end

lbt.api.persistent_data_delete = function (key)
  lbt.system.persistent_data[key] = nil
end

-- Template initialisation is a chance to set required state like counters.
-- Therefore, the _default_ template initialisation is a function that does nothing.
lbt.api.default_template_init = function()
  return function ()
    -- do nothing
  end
end

-- Template expansion acts on a parsed content (plus sources and options) and
-- produces a string of Latex code.
--
-- A template that is a structural will provide its own expand() function to
-- lay out the page as needed. A template that is content-based has no need
-- to do this, so it can lean on this default implementation.
--
-- The default expansion is to run the contents of BODY through
-- `lbt.fn.latex_for_commands`. That means this expansion is assuming that the author
-- content includes a '+[BODY]' somewhere. We raise an error if it does not exist.
--
-- To use this, include something like the following in a template file:
--
--   return {
--     name      = 'lbt.Basic',
--     desc      = 'Fundamental Latex macros for everyday use (built in to lbt)',
--     sources   = {},
--     init      = nil,
--     expand    = lbt.api.default_template_expander(),
--     functions = f,
--     posargs = a,
--     opargs = o,
--   }
--
lbt.api.default_template_expander = function()
  return function (pc)
    -- abbreviations for: parsed content, opcode resolver, option lookup
    lbt.log(4, 'Inside default_template_expander function for template <%s>', pc:template_name())
    local body = pc:list_or_nil('BODY')
    lbt.log(4, ' * BODY has <%d> items to expand', body:len())
    if body == nil then
      lbt.err.E301_default_expand_failed_no_body()
    end
    return lbt.fn.latex_for_commands(body)
  end
end

lbt.api.add_global_opargs = function (text)
  local opargs = lbt.parser.parse_dictionary(text)
  if opargs then
    lbt.log(3, 'Global opargs are being added to the stack:')
    lbt.log(3, lbt.pp(opargs))
    lbt.system.opargs_global:push(opargs)
    return nil
  else
    lbt.err.E945_invalid_oparg_dictionary_global(text)
  end
end

lbt.api.lbt_settings = function (text)
  local settings = lbt.parser.parse_dictionary(text)
  if settings then
    lbt.fn.apply_lbt_settings(settings)
  else
    lbt.err.E948_invalid_settings_dictionary(text)
  end
end

-- Usage: macro_define('\myvec=lbt.Math.myvec')
--
-- This looks up the module lbt.Math and sees if it has a macro 'myvec', which
-- is a function. Then it defines a Latex macro \myvec like so (without any newlines):
--
--   \newcommand{\myvec}[1]{
--     \luaexec{lbt.api.macro_run {
--       template = 'Math', macro = 'myvec', eid = lbt.fn.current_expansion_id(), arg = '#1'
--     }
--   }
--
-- It literally just prints that into the Latex stream. And logs it.
--
-- The current_expansion_id is needed so that the relevant ExpansionContext can be
-- retrieved when it is time to 'run' the macro.
-- XXX: this function is on the way out, but move the comment above to lbt.fn
lbt.api.macro_define = function (text)
  -- lm = latex macro   tn = template name   fn = function name
  local lm, tn, fn = lbt.fn.parse_macro_define_argument(text)
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

-- XXX: document the function here
lbt.api.define_latex_macros = function (text)
  local d = lbt.parser.parse_dictionary(text)
  if d == nil then
    lbt.err.E002_general("Attempt to \\lbtDefineLatexMacros failed: couldn't parse dictionary")
  end
  for key, value in pl.Map(d):iter() do
    lbt.fn.define_latex_macro(key, value)
  end
end

-- Usage:
--  * author sets up \myvec macro with \lbtDefineLatexMacro{\myvec=lbt.Math:myvec}
--  * author writes \myvec{4 6 -1} in their document
--  * lbt.api.macro_run { template = 'Math', macro = 'myvec', eid = 113, arg = '4 6 -1'}
--    is called
--  * Latex code is generated and emitted
-- Note:
--  * the eid is nil if the macro occurs outside an LBT expansion, in which case
--    lbt.gn.get_expansion_context_by_eid(nil) returns a skeleton context
lbt.api.macro_run = function (t)
  local tn = t.template   -- tn is 'template name' (e.g. Math)
  local fn = t.macro      -- fn is 'function name' (e.g. myvec)
  local eid = t.eid       -- expansion id for the LBT document in which the macro call occurred
  local arg = t.arg       -- the argument to the macro (e.g. '4 6 -1')
  local template = lbt.fn.Template.object_by_name_or_nil(tn)
  if template == nil then
    lbt.err.E159_macro_run_error("Template doesn't exist: %s", tn)
  end
  local f = template.macros[fn]
  if f == nil then
    lbt.err.E159_macro_run_error("Template %s does not have macro function %s", tn, fn)
  else
    local ctx = lbt.fn.get_expansion_context_by_eid(eid)
    local latex_code = f(arg, ctx)
    lbt.util.print_tex_lines(latex_code)
  end
end
