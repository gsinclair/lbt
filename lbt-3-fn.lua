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
  lbt.log(4, "lbt.fn.author_content_clear()")
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
  -- Detect debug and act accordingly.
  if pragmas.debug then
    lbt.fn.set_log_channels_for_debugging_single_expansion()
  end
  -- Local variables know whether we are appending to a list or a dictionary,
  -- and what current key in the results table we are appending to.
  local append_mode = nil
  local current_key = nil
  -- Process each line. It could be something like @META or something like +BODY,
  -- or something like "TEXT There once was a man from St Ives...".
  for line in lines:iter() do
    lbt.log('parse', "Parsing line: <<%s>>", line)
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
      -- We have a (hopefully valid) token, possibly with some text afterwards.
      local token, text = lbt.fn.impl.token_and_text(line)
      if token == nil then
        lbt.err.E001_internal_logic_error('somehow token is nil')
      end
      if not lbt.fn.impl.valid_token(token) then
        lbt.err.E100_invalid_token(token)
      end
      if append_mode == nil or current_key == nil then
        lbt.err.E101_line_out_of_place(line)
      end
      if append_mode == 'dict' then
        -- Put key and value in dictionary (note...no splitting...this may change)
        if text == nil then lbt.err.E105_dictionary_key_without_value(line) end
        result[current_key][token] = text
      elseif append_mode == 'list' and text == nil then
        local parsedline = {
          token = token,
          nargs = 0,
          args  = pl.List(),
          raw   = ""
        }
        result[current_key]:append(parsedline)
      elseif append_mode == 'list' and text ~= nil then
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

-- Returns a List.
lbt.fn.latex_expansion = function (parsed_content)
  local pc = parsed_content
  local t = lbt.fn.pc.template_object(pc)
  -- Obtain token and style resolvers so that expansion can occur.
  local tr, sr = lbt.fn.token_and_style_resolvers(pc)
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  lbt.log(4, 'About to latex-expand template <%s>', lbt.fn.pc.template_name(pc))
  return t.expand(pc, tr, sr)
end

-- Return List of strings, each containing Latex for a line of author content.
-- If a line cannot be evaluated (no function to support a given token) then
-- we insert some bold red information into the Latex so the author can see,
-- rather than halt the processing.
--
-- body: List of parsed lines
-- tr:   template resolver       call tr('Q') to resolve token Q to a function
-- sr:   style resolver          call s.get('Q.vspace') to get the value
lbt.fn.parsed_content_to_latex_multi = function (body, tr, sr)
  local buffer = pl.List()
  for line in body:iter() do
    local status, latex = lbt.fn.parsed_content_to_latex_single(line, tr, sr)
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
-- Before sending the arguments to the token function, any register references
-- like ◊ABC are expanded.
--
-- Parameters:
--  * line: parsed author content
--  * tr:   a token resolver that we call to get a token function
--  * sr:   a style resolver that we pass to the function for token expansion
--
-- Return:
--  * 'ok', latex       [succesful]
--  * 'sto', nil        [STO register allocation]
--  * 'notfound', nil   [token not found among sources]
--  * 'error', details  [error occurred while processing token]
--
-- Side effect:
--  * lbt.var.line_count is increased (unless this is a register allocation)
--  * lbt.var.registers might be updated
lbt.fn.parsed_content_to_latex_single = function (line, tr, sr)
  lbt.log(4, 'parsed_content_to_latex_single: %s', lbt.fn.pc.compact_representation_line(line))
  lbt.log('emit', '')
  lbt.log('emit', 'Line: %s', lbt.fn.pc.compact_representation_line(line))
  local token = line.token
  local nargs = line.nargs
  local args  = line.args
  -- 1. Handle a register allocation. Do not increment linecount.
  if token == 'STO' then
    lbt.fn.impl.assign_register(line)
    return 'sto', nil
  end
  -- 2. Search for a token function and return if we did not find one.
  local findings = tr(token)
  if findings == nil then
    lbt.log('emit', '    --> NOTFOUND')
    lbt.log(2, 'Token not resolved: %s', token)
    return 'notfound', nil
  end
  local token_function, argspec = table.unpack(findings)
  -- 3. Check we have a valid number of arguments.
  if argspec then
    local a = argspec
    if nargs < a.min or nargs > a.max then
      local msg = F("%d args given but %s expected", nargs, a.spec)
      lbt.log('emit', '    --> ERROR: %s', msg)
      lbt.log(1, 'Error attempting to expand token:\n    %s', msg)
      return 'error', msg
    end
  end
  -- 4. We really are processing a token, so we can increase the token_count.
  lbt.fn.impl.inc_token_count()
  -- 5. Expand register references where necessary.
  --    We are not necessarily in mathmode, hence false.
  args = args:map(lbt.fn.impl.expand_register_references, false)
  -- 6. Call the token function and return 'ok', ... or 'error', ...
  result = token_function(nargs, args, sr)
  if type(result) == 'string' then
    lbt.log('emit', '    --> %s', result)
    return 'ok', result
  elseif type(result) == 'table' and type(result.error) == 'string' then
    local errormsg = result.error
    lbt.log('emit', '    --> ERROR: %s', errormsg)
    lbt.log(1, 'Error occurred while processing token %s\n    %s', token, errormsg)
    return 'error', errormsg
  elseif type(result) == 'table' then
    result = table.concat(result, "\n")
    lbt.log('emit', '    --> %s', result)
    return 'ok', result
  else
    lbt.E325_invalid_return_from_template_function(result)
  end
end

-- From one parsed-content object, we can derive a token resolve and a style
-- resolver.
lbt.fn.token_and_style_resolvers = function (pc)
  -- The name of the template allows us to retrieve the template object.
  local t = lbt.fn.pc.template_object(pc)
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
lbt.fn.token_resolver = function (sources)
  return pl.utils.memoize(function (token)
    for s in sources:iter() do
      -- Each 'source' is a template object, with properties 'functions'
      -- and 'arguments'.
      local f = s.functions[token]
      local a = s.arguments[token]
      if f then
        if a == nil then
          lbt.log(2, 'WARN: no argspec provided for token <%s>', token)
        end
        return {f, a}
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

-- }}}

--------------------------------------------------------------------------------
-- {{{ Functions associated with parsed content
--  * meta(pc)
--  * title(pc)
--  * dictionary(pc, "META")
--  * list(pc, "BODY")
--  * template_name(pc)
--  * template_object(pc)
--  * extra_sources(pc)
--  * extra_styles(pc)
--  * compact_representation(pc)       for debugging
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

lbt.fn.pc.template_object = function (pc)
  local tn = lbt.fn.pc.template_name(pc)
  local t = lbt.fn.template_object_or_error(tn)
  return t
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

-- Return a Map of style settings given in META.STYLES.
-- May be empty.
lbt.fn.pc.extra_styles = function (pc)
  local styles = pc.META.STYLES
  if styles then
    return lbt.fn.style_string_to_map(styles)
  else
    return pl.Map()
  end
end

lbt.fn.pc.compact_representation_line = function(pc_line)
  return F("%s | %s", pc_line.token, pc_line.raw:shorten(60))
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
  -- Same as above, but with styles.
  if td.styles then
    local ok, x = lbt.fn.impl.template_styles_specification(td.styles)
    if ok then
      td.styles = x
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
  local src1 = lbt.fn.pc.extra_sources(pc)  -- optional specific source names (List)
  local src2 = pl.List(t.sources)           -- source names baked in to the template (List)
  local sources = pl.List();
  do
    sources:extend(src1);
    sources:append(t.name)                  -- the template itself has to go in there
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
--  * docwide        a Map of document-wide styles (i.e. lbt.system.d_w_s)
--  * pc             parsed content, which gives us access to STYLES
--  * templates      consolidated list of templates in precedence order
--                   (we extract the 'styles' map from each)
-- 
-- Return:
--  * a pl.Map of all style mappings, respecting precedence
--
-- Errors:
--  * none that I can think of
--
lbt.fn.impl.consolidated_styles = function (docwide, pc, sources)
  lbt.log('styles', '')
  local result = pl.Map()
  local styles = nil
  for s in pl.List(sources):reverse():iter() do
    styles = s.styles or pl.Map()
    lbt.log('styles', 'extracting styles from <%s>: %s', s.name, styles)
    result:update(styles)
    -- I(result)
  end
  styles = docwide
  lbt.log('styles', 'extracting document-wide styles:', styles)
  result:update(styles)
  -- I(result)
  styles = lbt.fn.pc.extra_styles(pc)
  lbt.log('styles', 'extracting styles from parsed content: %s', styles)
  result:update(styles)
  -- IX(result)
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

lbt.fn.impl.latex_message_token_not_resolved = function (token)
  return F([[\textcolor{red}{textbf{Token %s not resolved}}]], token)
end

lbt.fn.impl.latex_message_token_raised_error = function (token, err)
  return F([[\textcolor{red}{textbf{Token %s raised error: \emph{%s}} }]], token, err)
end

lbt.fn.impl.assign_register = function (line)
  if line.nargs ~= 3 then
    lbt.err.E318_invalid_register_assignment_nargs(line)
  end
  local regname, ttl, defn = table.unpack(line.args)
  local regname, mathmode = lbt.fn.impl.register_name_and_mathmode(regname)
  local value = lbt.fn.impl.expand_register_references(defn, mathmode)
  local record = { name     = regname,
                   exp      = lbt.fn.impl.current_token_count() + ttl,
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

lbt.fn.impl.current_token_count = function ()
  local token_count = lbt.var.token_count
  if token_count == nil then
    lbt.err.E001_internal_logic_error('current token_count not set')
  end
  return token_count
end

lbt.fn.impl.inc_token_count = function ()
  local token_count = lbt.var.token_count
  if token_count == nil then
    lbt.err.E001_internal_logic_error('current token_count not set')
  end
  lbt.var.token_count = token_count + 1
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
  -- DEBUGGER()
  if re == nil then
    return 'nonexistent', nil
  elseif lbt.fn.impl.current_token_count() > re.exp then
    return 'stale', nil
  else
    return 'ok', re.value, re.mathmode
  end
end

-- $Delta    ->   Delta, true
-- fn1       ->   fn1, false
lbt.fn.impl.register_name_and_mathmode = function (text)
  local name = nil
  local mathmode = false
  if text:startswith('$') then
    mathmode = true
    name = text:sub(2)
  else
    name = text
  end
  if name:match('^[A-z][A-z0-9]*$') then
    return name, mathmode
  else
    lbt.err.E309_invalid_register_name(name)
  end
end

lbt.fn.impl.sources_list_compact_representation = function (sources)
  local name = function (td) return td.name end
  return sources:map(name):join(', ')
end

-- }}}
