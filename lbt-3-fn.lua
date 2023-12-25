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
        lbt.err.E001_internal_logic_error("append_mode: %s", append_mode)
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
  -- Find the main template for the parsed content.
  local pc = parsed_content
  local tn = lbt.fn.pc.template_name(pc)
  local t = lbt.fn.template_object_or_error(tn)
  -- Calculate the consolidated sources and styles.
  -- Save styles in a global variable to token expansion can work.
  local src = lbt.fn.impl.consolidated_sources(pc, t)
  local sty = lbt.fn.impl.consolidated_styles(pc, t)
  lbt.fn.set_styles_for_current_expansion(sty)
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  local r = lbt.fn.resolver(src)
  return t.expand(pc, r)
end

-- Return List of strings, each containing Latex for a line of author content.
-- If a line cannot be evaluated (no function to support a given token) then
-- we insert some bold red information into the Latex so the author can see,
-- rather than halt the processing.
--
-- Note: relies on global variables for sources and styles.
lbt.fn.parsed_content_to_latex_multi = function (body, resolver)
  local buffer = pl.List()
  for line in body:iter() do
    local status, latex = lbt.fn.parsed_content_to_latex_single(line, resolver)
    if status == 'ok' then
      buffer:append(latex)
    elseif status == 'notfound' then
      local msg = lbt.fn.impl.latex_message_token_not_resolved(line.token)
      buffer:append(msg)
    elseif status == 'error' then
      local err = latex
      local msg = lbt.fn.impl.latex_message_token_raised_error(line.token, err)
      buffer:append(msg)
    end
  end
  return buffer
end

-- Take a single line of parsed author content (table with keys token, nargs,
-- args and raw) and produce a string of Latex.
--
-- Return:
--  * 'ok', latex       [succesful]
--  * 'notfound', nil   [token not found among sources]
--  * 'error', details  [error occurred while processing token]
--
-- Note: relies on global variables for sources and styles.
lbt.fn.parsed_content_to_latex_single = function (line, resolver)
  local token = line.token
  local nargs = line.nargs
  local args  = line.args
  local token_function = resolver(token)
  -- IDEA ^^^ get the function and the expected number of arguments,
  --          and do the arg-checking _here_ instead of in every template
  --          function.
  if token_function == nil then
    return 'notfound', nil
  end
  stat, x = token_function(nargs, args)
  lbt.dbg('lbt.fn.parsed_content_to_latex_single')
  lbt.dbg('  token & args: %s  %s', token, args)
  lbt.dbg('  result (stat, x): %s   %s', stat, x)
  if stat == 'ok' then
    return 'ok', x
  elseif stat == 'nargs' then
    local msg = F("%d args given but %s expected", nargs, x)
    return 'error', msg
  elseif stat == 'error' then
    return 'error', x
  end
end

-- Produce a function that looks through all sources (as provided here) in
-- order until a function of the given name is found, or returns nil if none is
-- found.
lbt.fn.resolver = function (sources)
  local cache = {}
  return function (token)
    if cache[token] ~= nil then
      return cache[token]
    else
      for s in sources:iter() do
        -- Each 'source' is a template object, with property 'functions'.
        local f = s.functions[token]
        if f then
          cache[token] = f
          return f
        end
      end
      -- No token function found :(
      return nil
    end
  end
end

-- This is called once when the parsed content is about to be Latexified.
lbt.fn.set_styles_for_current_expansion = function (sty)
  assert_table(1, sty)      -- a dictionary-style table
  if lbt.const.styles == nil then
    lbt.const.styles = sty
  else
    local msg = 'set_styles_for_current_expansion should be called only once per expansion'
    lbt.err.E001_internal_logic_error(msg)
  end
end

-- This is called in template functions to produce appropriate Latex code.
lbt.fn.style = function (key)
  local value = lbt.const.styles[key]
  if value == nil then
    local msg = F("There is no style for key <%s>, which means you've made an error", key)
  else
    return value
  end
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
  local d = pc[key]
  if d == nil then
    lbt.err.E303_content_dictinary_not_found(pc, key)
  end
  return d
end

lbt.fn.pc.content_list = function (pc, key)
  local l = pc[key]
  if l == nil then
    lbt.err.E302_content_list_not_found(pc, key)
  end
  return l
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
      lbt.log(F("WARN: Template name <%s> already exists; overwriting.", tn))
      lbt.log(F("       * existing path: %s", curr_path))
      lbt.log(F("       * new path:      %s", path))
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

lbt.fn.template_register_to_logfile = function()
  local tr = lbt.system.template_register
  lbt.log("")
  lbt.log("The template register appears below.")
  lbt.log("")
  lbt.log(pp(tr))
end
--}}}

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
-- It is imperative that lbt.Basic appear somewhere, without having to be named
-- by the user. It might as well appear at the end, so we add it.
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
  local basic = lbt.fn.template_object_or_error("lbt.Basic")
  result:append(basic)
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

lbt.fn.impl.latex_message_token_not_resolved = function (token)
  return F([[\textcolor{red}{textbf{Token %s not resolved}}]], token)
end

lbt.fn.impl.latex_message_token_raised_error = function (token, err)
  return F([[\textcolor{red}{textbf{Token %s raised error: \emph{%s}}}]], token, err)
end
-- }}}
