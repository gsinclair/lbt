--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

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

--------------------------------------------------------------------------------
-- Author content:
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

--------------------------------------------------------------------------------
-- Processing author content and emitting Latex code
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
  local t = lbt.fn.template(tn)
  INSPECTX("Template object", t)
  local src = lbt.fn.impl.consolidated_sources(pc)
  local sty = lbt.fn.impl.consolidated_styles(pc)
  -- Allow the template to initialise counters, etc.
  t.init()
  -- And...go!
  return t.expand(pc, src, sty)
end

--------------------------------------------------------------------------------
-- Functions associated with parsed content
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

lbt.fn.pc.extra_sources = function (pc)
  ENI()
end

--------------------------------------------------------------------------------
-- Functions to do with loading templates
--  * initialise_template_register
--  * load_template_into_register(name)
--  * template(name)
--------------------------------------------------------------------------------

-- TODO make this fn.impl ?
local function validate_template_object(name, path, t)
  if type(t) ~= 'table' then
    lbt.err.E401_invalid_template_object(name, path, "not a table")
  end
  if t.name == nil or t.sources == nil or t.init == nil or t.expand == nil or t.functions == nil then
    lbt.err.E401_invalid_template_object(name, path, "missing one or more pieces of information")
  end
end

-- TODO make this fn.impl ?
-- Result: lbt.system.templates has new entry `name` -> { path = path, template = nil }
local function template_register_add_path (name, path)
  if pl.path.exists(path) == false then
    lib.err.E403_template_path_doesnt_exist(name, path)
  end
  validate_template_object(name, path, template)
  lbt.system.templates[name] = { path = path, template = nil }
  lbt.log(F("Template register: name <%s> --> path <%s>", name, path))
end

-- TODO make this fn.impl ?
-- Result: lbt.system.templates has updated entry `name` -> { path = path, template = (object) }
local function template_register_realise_object (name)
  local entry = lbt.system.templates[name]
  if entry == nil then
    lbt.err.E404_template_name_not_registered(name)
  end
  local path = entry.path
  local ok, template = pcall(dofile(path))
  if ok == false then
    lbt.err.E400_cant_load_template(name, path)
  end
  validate_template_object(name, path, template)
  lbt.system.templates[name] = { path = path, template = template }
  lbt.log(F("Template register: realised template with name <%s>", name))
end

-- Result: lbt.system.templates has an entry for every possible template the user
--         can access, whether built-in, contrib, or user-side.
lbt.fn.initialise_template_register = function ()
  local templates = lbt.system.tempates
  if pl.tablex.size(tempates) > 0 then
    return templates
  end
  template_register_add_path("Basic", "templates/Basic.lua")
  template_register_realise_object("Basic")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Load all templates defined in lib/templates/*.lua
-- Result is cached, so this function may be called freely.
lbt.fn.template_table = function()
  if lbt.system.templates_loaded == false then
    local filenames = io.popen([[ls lib/templates/*.lua]])
    for filename in filenames:lines() do
      local _, _, template_name = string.find(filename, "/([A-z0-9_-]+)%.lua$")
      local template_object = dofile(filename)
      assert(template_name, "Unable to find template file: "..filename)
      assert(template_object, "Unable to load template object")
      lbt.system.templates[template_name] = template_object
      lbt.dbg("Template table: %s --> %s", template_name, filename)
    end
    lbt.dbg("Loaded templates table for the first time:")
    lbt.dbg(pp(lbt.system.templates))
  else
    lbt.system.templates_loaded = true
    return lbt.system.templates
  end
end

-- TODO rename (or remove), and maybe reimplement
lbt.fn.string = function()
  local result = {"lbt.content"}
  for key, T in pairs(lbt.content) do
    -- First level.
    table.insert(result, "  " .. key)
    if T[1] == nil then
      -- We have a dictionary
      for token,text in pairs(T) do
        table.insert(result, F("    %-15s  %s", token, text:sub(1,35)))
      end
    else
      -- We have a list
      for _, vals in ipairs(T) do
        local token, text = table.unpack(vals)
        table.insert(result, F("    %-15s  %s", token, text:sub(1,35)))
      end
    end
  end
  return table.concat(result, "\n")
end

lbt.fn.template = function(name)
  -- TODO consider a different name, like template_by_name.
  local tt = lbt.fn.template_table()
  local t  = tt[name]
  if t == nil then
    lbt.err.E200_no_template_for_name(name)
  end
  return t
end

--------------------------------------------------------------------------------
-- Functions assisting the implementation. These are lower-level in nature and
-- just do one thing with the argument(s) they are given.
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
