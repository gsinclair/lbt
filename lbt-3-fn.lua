--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

-- {{{ Preamble: local conveniences
local assert_string = pl.utils.assert_string
local assert_bool = function(n,x) pl.utils.assert_arg(n,x,'boolean') end
local assert_table = function(n,x) pl.utils.assert_arg(n,x,'table') end

local P = lbt.util.tex_print_formatted

local F = string.format

-- alias for pretty-printing a table
local pp = pl.pretty.write

local ENI = function()
  error("Not implemented", 3)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Author content:
--  * author_content_clear      (reset lbt.const and lbt.var data)
--  * author_content_append     (append stripped line to lbt.const.author_content,
--                               handling » continuations)
--------------------------------------------------------------------------------

lbt.fn.author_content_clear = function()
  lbt.dbg("lbt.fn.author_content_clear() -- starting a new lbt collection phase")
  lbt.dbg("    Filename: %s   Line number: %d", status.filename, status.linenumber)
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.fn.author_content_append = function(line)
  line_list = lbt.const.author_content
  line = line:strip()
  if line == "" then return end
  if line:sub(1,2) == "»" then
    -- Continuation of previous line
    prev_line = line_list:pop()
    if prev_line == nil then
      lbt.err.E103_invalid_line_continuation(line)
    end
    line = prev_line .. " " .. line:sub(3,-1)
  end
  lbt.const.author_content:append(line)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Processing author content and emitting Latex code
--  * parsed_content(c)        (internal representation of the author's content)
--  * latex_expansion(pc)      (Latex representation based on the parsed content)
--------------------------------------------------------------------------------

-- parsed_content(c)
--
-- Input: list of raw stripped lines from the `lbt` environment
--        (no need to worry about line continuations)
-- Output: { pragmas: Set(...),
--           META: {...},
--           BODY: List(...),
--           ...}
--
-- Note: each item in META, BODY etc. is of the form
--   {token:'BEGIN' nargs:2, args:List('multicols','2') raw:'multicols 2'}
--
lbt.fn.parsed_content = function (content_lines)
  assert_table(1, content_lines)
  -- Obtain pragmas (set) and non-pragma lines (list), and set up result table.
  local pragmas, lines = lbt.fn.impl.pragmas_and_other_lines(content_lines)
  local result = { pragmas = pragmas }
  -- Detect ignore and act accordingly.
  if pragmas.ignore then
    return result
  end
  -- Local variables know whether we are appending to a list or a dictionary,
  -- and what current key in the results table we are appending to.
  local append_mode = nil
  local current_key = nil
  -- Process each line. It could be something like @META or something like +BODY,
  -- or something like "TEXT There once was a man from St Ives...".
  for line in lines:iter() do
    lbt.dbg("Processing line: <<%s>>", line)
    if line:at(1) == '@' then
      -- We have @META or similar, which acts as a dictionary.
      current_key = lbt.fn.impl.validate_content_key(line, result)
      append_mode = 'dict'
      result[current_key] = {}
    elseif line:at(1) == '+' then
      -- We have +BODY or similar, which acts as a list.
      current_key = lbt.fn.impl.validate_content_key(line, result)
      append_mode = 'list'
      result[current_key] = pl.List()
    else
      local token, text = line:match("^(%u+)%s*(.*)$")
      -- We have a valid token, possibly with some text afterwards.
      if token == nil then lbt.err.E100_invalid_token(line) end
      if append_mode == nil or current_key == nil then lbt.err.E101_line_out_of_place(line) end
      if append_mode == 'dict' then
        if text == nil then lbt.err.E105_dictionary_key_without_value(line) end
        result[current_key][token] = text
      elseif append_mode == 'list' then
        -- The text needs to be split into arguments.
        local args = pl.utils.split(text, "%s+::%s+")
        local parsedline = {
          token = token,
          nargs = #args,
          args  = pl.List.new(args),
          raw   = text
        }
        result[current_key]:append(parsedline)
      else
        lbt.err.E000_internal_logic_error("append_mode: %s", append_mode)
      end
    end
  end
  return result
end

lbt.fn.validate_parsed_content = function (pc)
  -- We check that META and META.TEMPLATE are present.
  local m = pc.META
  if m == nil then
    lbt.err.E203_no_META_defined()
  end
  local t = pc.META.TEMPLATE
  if t == nil then
    lbt.err.E204_no_TEMPLATE_defined()
  end
  return nil
end

lbt.fn.latex_expansion = function (parsed_content)
  local pc = parsed_content
  local tn = lbt.fn.pc.template_name(pc)
  local t = lbt.fn.template_object_or_error(tn)
  local src = lbt.fn.impl.consolidated_sources(pc, t)
  INSPECTX("Consolidated sources", src)
  local sty = lbt.fn.impl.consolidated_styles(pc, t)
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  return t.expand(pc, src, sty)
end
-- }}}

--------------------------------------------------------------------------------
-- {{{ Functions associated with parsed content
--  * meta(pc)
--  * title(pc)
--  * dictionary(pc, "META")
--  * list(pc, "BODY")
--  * template_name(pc)
--  * extra_sources(pc)
--------------------------------------------------------------------------------

lbt.fn.pc = {}

lbt.fn.pc.meta = function (pc)
  return pc.META
end

lbt.fn.pc.title = function (pc)
  return pc.META.TITLE or "(no title)"
end

lbt.fn.pc.template_name = function (pc)
  return pc.META.TEMPLATE
end

lbt.fn.pc.content_dictionary = function (pc, key)
  ENI()
end

lbt.fn.pc.content_list = function (pc, key)
  ENI()
end

-- Return a List of template names given in META.SOURCES.
-- May be empty.
lbt.fn.pc.extra_sources = function (pc)
  local sources = pc.META.SOURCES
  if sources then
    local bits = sources:split(",")
    return pl.List(bits):map(pl.stringx.strip)
  else
    return pl.List()
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
--------------------------------------------------------------------------------

lbt.fn.expand_directory = function (path)
  if path:startswith("PWD") then
    return path:replace("PWD", os.getenv("PWD"), 1)
  elseif path:startswith("TEXMF") then
    lbt.err.E001_internal_logic_error("not implemented")
  else
    lbt.err.E207_invalid_template_path(path)
  end
end

lbt.fn.register_template = function(template_details, path)
  local td = template_details
  local tn = template_details.name
  ok, err_detail = lbt.fn.impl.template_details_are_valid(td)
  if ok then
    if lbt.fn.template_object_or_nil(tn) ~= nil then
      local curr_path = lbt.fn.template_path_or_error(tn)
      lbt.log(F("WARN: Template name <%s> already exists; overwriting.", tn))
      lbt.log(F("       * existing path: %s", curr_path))
      lbt.log(F("       * new path:      %s", path))
    end
    lbt.system.template_register[tn] = { td = td, path = path }
  else
    lbt.err.E215_invalid_template_details(td, path, err_detail)
  end
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

--------------------------------------------------------------------------------
-- {{{ Miscellaneous old code to be integrated or reconsidered
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Functions assisting the implementation.
-- These are lower-level in nature and just do one thing with the argument(s)
-- they are given.
--  * xxx
--  * xxx
--  * xxx
--  * xxx
--------------------------------------------------------------------------------

lbt.fn.impl = {}

local update_pragma_set = function(pragmas, line)
  p = line:match("!(%u+)$")
  if     p == 'DRAFT'    then pragmas.draft  = true
  elseif p == 'NODRAFT'  then pragmas.draft  = false
  elseif p == 'IGNORE'   then pragmas.ignore = true
  elseif p == 'NOIGNORE' then pragmas.ignore = false
  elseif p == 'DEBUG'    then pragmas.debug  = true
  elseif p == 'NODEBUG'  then pragmas.debug  = false
  else
    lbt.err.E102_invalid_pragma(line)
  end
end

-- Extract pragmas from the lines into a table.
-- Return a table of pragmas (draft, debug, ignore) and a List of non-pragma lines.
lbt.fn.impl.pragmas_and_other_lines = function(input_lines)
  pragmas = { draft = false, ignore = false, debug = false }
  lines   = pl.List()
  for line in input_lines:iter() do
    if line:at(1) == '!' then
      update_pragma_set(pragmas, line)
    else
      lines:append(line)
    end
  end
  return pragmas, lines
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

-- lbt.fn.impl.consolidated_sources(pc,t)
-- 
-- A template itself has sources. For example, Exam might rely on Questions and Figures.
-- A specific expansion optionally has extra sources defined in @META.SOURCES.
-- The specific ones take precedence.
--
-- Return: a List of source template _objects_ in the order they should be referenced.
-- Error: if any template name cannot be resolved into a template object.
--
lbt.fn.impl.consolidated_sources = function (pc, t)
  local src1 = lbt.fn.pc.extra_sources(pc)  -- optional specific source names (List)
  local src2 = pl.List(t.sources)           -- source names baked in to the template (List)
  local sources = pl.List(); sources:extend(src1); sources:extend(src2)
  local result = pl.List()
  for name in sources:iter() do
    local t = lbt.fn.template_object_or_nil(name)
    if t then
      result:append(t)
    else
      lbt.err.E206_cant_form_list_of_sources(name)
    end
  end
  return result
end

-- lbt.fn.impl.consolidated_styles(pc,t)
-- 
-- Like sources, a template has styles (not yet implemented) and these can be overridden
-- in a number of ways (not yet fully defined).
--
-- Return: a dictionary of style mappings like "Q.space -> 6pt"
-- Error: ...
--
lbt.fn.impl.consolidated_styles = function (pc, t)
  return { placeholder = "hello" }
end

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
  elseif type(td.init) ~= 'function' then
    return false, F('init is not a function')
  elseif type(td.expand) ~= 'function' then
    return false, F('expand is not a function')
  elseif type(td.functions) ~= 'table' then
    return false, F('functions is not a table')
  end
  return true, ''
end
-- }}}
