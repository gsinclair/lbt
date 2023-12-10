require 'lib.gsHelpers'
dbg = require 'lib.debugger'

-- [[                                    ]]
-- [[          useful functions          ]]
-- [[                                    ]]

LOG = io.open("debug.log", "w")

function gsdebug(text, ...)
  text = text or ''
  text = string.format(text, ...)
  LOG:write(text.."\n")
end

pp = pprint.pformat

F = string.format

function P(text, ...)
  tex.print(F(text, ...))
end

function print_tex_lines(str)
  typecheck(str, 'string')
  tex.print(magiclines(str))
end

-- A useful higher-order function for implementing simple template tokens.
-- \par is appended so that this latex command will be its own paragraph.
-- e.g.   Q = latex_command_par('questionQ')
function latex_command_par(cmd)
  return function(arg)
    return F([[\%s{%s} \par]], cmd, arg)
  end
end

-- As above but without the paragraph.
-- e.g.   B = latex_command_inline('textbf')
function latex_command_inline(cmd)
  return function(arg)
    return F([[\%s{%s}]], cmd, arg)
  end
end

-- As above but without any argument.
-- e.g.   V = latex_command_plain('vfill')
function latex_command_plain(cmd)
  return function(_)
    return F([[\%s]], cmd)
  end
end

-- TODO make one or more functions for environments, like the ones above

-- [[                                    ]]
-- [[                API                 ]]
-- [[                                    ]]

-- GSC == Gavin Sinclair Content
-- A better name would be nice.
-- Several parts to it:
--  * state is an implementation detail for processing content and emitting Latex
--  * api contains API functions to be called externally or internally
--  * fn contains implementation functions
--  * util contains utility functions
--  * test contains testing functions
--  * content is populated by api.populate_content() and is cleared each time a new
--    gsContent Latex environment is encountered
--  * macros contains Lua implementation of Latex macros (currently: error, defint, indefint)
GSC = {
  state = {                        -- variables assisting implementation
    templates_loaded = false,
    templates = {},
    append_mode = nil,
    current_key = nil,
    counters = {},
  },
  api = {},                        -- functions called externally
  fn = {},                         -- functions for the core implementation
  util = {},                       -- functions to help out
  test = {},                       -- functions for testing
  content = {},                    -- content data processed from Latex file
  data = {},                       -- a place where data can be stored to enhance content
  pragmas = {},                    -- draft, ignore, debug
  macros = require("lib.gsContent.macros")
}

-- This is called by the Latex environment gsContent: at the beginning, to clear
-- the content inside the GSC global variable.
GSC.api.clear_content = function()
  GSC.content = {}
  GSC.data    = {}
  GSC.pragmas = {}
end

-- This is called by the Latex environment gsContent: in the middle, to populate
-- the global variable with all the structured textual information needed to
-- generate the Latex code.
GSC.api.populate_content = function(text)
  typecheck(text, 'string')
  GSC.fn.populate_content_and_pragmas(text)
end

-- This is called by the Latex environment gsContent: at the end, to actually
-- produce the Latex code.
GSC.api.emit_tex = function()
  GSC.fn.emit_tex()
end

-- Called directly in a Lua block from Latex code.
-- If true, populate_content will short-circuit to (nearly) a no-op unless the first line of content is DRAFT.
-- This will speed up compilation.
GSC.api.set_draft_mode = function(x)
  assert(type(x) == 'boolean')
  GSC.state.draft_mode = x
end

GSC.api.get_draft_mode = function()
  return GSC.state.draft_mode
end

-- Counters are auto-created, so this will always return a value. The initial will be zero.
GSC.api.counter_value = function(c)
  GSC.state.counters[c] = GSC.state.counters[c] or 0
  return GSC.state.counters[c]
end

GSC.api.counter_set = function(c, v)
  GSC.state.counters[c] = v
end

GSC.api.counter_reset = function(c)
  GSC.state.counters[c] = 0
end

GSC.api.counter_inc = function(c, v)
  local v = GSC.api.counter_value(c)
  GSC.api.counter_set(c, v+1)
  return v+1
end

GSC.api.data_get = function(key, initval)
  if GSC.data[key] == nil then
    GSC.data[key] = initval
  end
  return GSC.data[key]
end

GSC.api.data_set = function(key, value)
  GSC.data[key] = value
end

-- This is slightly hacky because this general GSC code shouldn't have knowledge of
-- specific counters. An alternative could be a table that specifies counters to be
-- reset upon a new chapter, or part, or section, or...
-- That alternative is not worth pursuing at the moment.
GSC.api.reset_chapter_counters = function()
  GSC.api.counter_reset('worksheet')
  GSC.api.counter_reset('quiz')
end

GSC.api.set_chapter_abbreviation = function (x)
  GSC.state.chapter_abbreviation = x
end

GSC.api.get_chapter_abbreviation = function ()
  return GSC.state.chapter_abbreviation
end


-- [[                                    ]]
-- [[              support               ]]
-- [[                                    ]]


GSC.fn.template_table = function()
  if GSC.state.templates_loaded == false then
    -- local filenames = io.popen([[ls lib/gsContent/*.lua]])
    local filenames = io.popen([[ls lib/templates/*.lua]])
    for filename in filenames:lines() do
      local _, _, template_name = string.find(filename, "/([A-z0-9_-]+)%.lua$")
      local template_object = dofile(filename)
      assert(template_name, "Unable to find template file: "..filename)
      assert(template_object, "Unable to load template object")
      GSC.state.templates[template_name] = template_object
      gsdebug("Template table: %s --> %s", template_name, filename)
    end
    gsdebug("Loaded templates table for the first time:")
    gsdebug(pp(GSC.state.templates))
  end
  GSC.state.templates_loaded = true
  return GSC.state.templates
end

GSC.fn.string = function()
  local result = {"GSC.content"}
  gsdebug(pp(GSC))
  for key, T in pairs(GSC.content) do
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

GSC.fn.resolve_template_name = function(name)
  return GSC.fn.template_table()[name]
end

-- [[                                    ]]
-- [[           implementation           ]]
-- [[                                    ]]

local function update_pragma_table(t, str)
  if str == "!DEBUG" then
    t.debug = true
  elseif str == "!IGNORE" then
    t.ignore = true
  elseif str == "!DRAFT" then
    t.draft = true
  elseif str == "!NODRAFT" then
    t.draft = false
  else
    error("Invalid pragma: " .. str)
  end
end

-- Return two values in a table:
--  * pragmas: a table like { draft = true, debug = true }
--             [recognised pragmas are DRAFT, IGNORE, DEBUG]
--  * lines: a list of trimmed, non-empty lines, in which continuations (using ») have
--           been collapsed into one line.
local function pre_process(text)
  local pragmas = {}
  local lines = {}
  local current_line = {}
  for line in magiclines(text) do
    -- if GSC.state.chapter_abbreviation == "AS" then dbg() end
    line = trim(line)
    if line:sub(1,1) == "" then
      -- Ignore empty lines
    elseif string.find(line, "^!%u+$") then
      -- We found a pragma
      update_pragma_table(pragmas, line)
    elseif line:sub(1,2) == "»" then
      gsdebug("GUILLEMET!")
      -- Collapse into current line
      if current_line == {} then
        error("Continuation line without a line to add to: " .. line)
      else
        table.insert(current_line, line:sub(3))
      end
    else
      -- This is the start of a line of text. Write out the previous one.
      previous_line = table.concat(current_line, "\n")
      if previous_line ~= "" then
        table.insert(lines, previous_line)
      end
      current_line = { line }
    end
  end
  final_line = table.concat(current_line, "\n")
  if final_line ~= "" then
    table.insert(lines, final_line)
  end
  return { pragmas = pragmas, lines = lines }
end

-- This function is called inside the Latex environment \gsContent.
-- It is a user-facing function, where the user is the content creator.
-- Its purpose is to build the global table GSC (Gavin Sincair Content).
-- It does that by processing the lines of text provided inside the [[ ... ]]
-- For instance:
--   begin{gsContent}
--     begin{luacode*}
--       GSC_content [[
--         @META
--           TITLE Integration (concepts)
--           TYPE  WS1
--
--         @INTRO
--           PROBLEM We want to calculate areas...
--           SOLUTION Approximate using thin rectangles...
--           ...
--
--         +BODY
--           EXAMPLE ...
--           Q ...
--           QQ ...
--       ]]
--     end{luacode*}
--   end{gsContent}
--
-- The outcome of that code is that the global GSC code is re-initialised,
-- then populated by parsing all the @META and TITLE and so on.
--
-- META and INTRO and BODY become keys in the GSC table.
--
-- @META and @INTRO have @ because their contents are key-value pairs. The @
-- represents a 'map'.
--
-- +BODY has a + becaues its contents are sequential token-text pairs.
--
-- Side-effects: GSC.pragmas and GSC.content are populated.
--
-- Return value: true if GSC.content was populated; false if not.
-- The only reason for false is !IGNORE.
--
GSC.fn.populate_content_and_pragmas = function(text_blob)
  typecheck(text_blob, 'string')
  gsdebug("*** GSC.fn.populate_content() called ***")

  -- 1. Preprocess text_blob into pragmas and (neat) lines. Deal with !DRAFT and !IGNORE.
  local pp = pre_process(text_blob)
  gsdebug([[>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> pp.lines (pre-processed)]])
  gsdebug(table.concat(pp.lines, "\n"))
  gsdebug([[<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<]])
  GSC.pragmas = pp.pragmas; pp.pragmas = nil
  if GSC.pragmas.ignore then
    return false
  end

  -- 2. Do the processing.
  for _, line in ipairs(pp.lines) do
    if line:sub(1,1) == '@' then
      -- We have a new key in the table that acts as a dictionary.
      local key = line:sub(2)
      GSC.content[key] = {}
      GSC.state.append_mode = 'dict'
      GSC.state.current_key = key
    elseif line:sub(1,1) == '+' then
      -- We have a new key in the table that acts as a list.
      local key = line:sub(2)
      GSC.content[key] = {}
      GSC.state.append_mode = 'list'
      GSC.state.current_key = key
    else
      -- This line contains data that we append to the current dictionary or list.
      local token, text = line:match("^(%S+)%s+(.*)$")
      local append_mode = GSC.state.append_mode
      local current_key = GSC.state.current_key
      if token == nil then
        error(F("Error in parsing line; no token. Line = [[%s]]", line))
      end
      if append_mode == nil or current_key == nil then
        gsdebug("Error in gsContent -- append_mode or current_key is nil")
        gsdebug("                      No @META or +BODY or ... set yet ???")
        os.exit()
      elseif append_mode == 'dict' then
        GSC.content[current_key][token] = text
      elseif append_mode == 'list' then
        table.insert(GSC.content[current_key], {token, text})
      else
        gsdebug("Logic error")
        os.exit()
      end
    end
    if GSC.pragmas.debug then dbg() end
  end
  gsdebug("DONE (populate_content)")
  return true
end

-- Return a string of Latex code, having found an implementation of the token among
-- the template names given.
-- If no implementation is found, then no token can be generated; return nil.
GSC.fn.tex_eval_single = function(token, text, template_names)
  typecheck(token, 'string')
  typecheck(text, 'string')
  typecheck(template_names, 'table')

  -- Resolve each template name, in order, and see if that template can handle the token.
  -- If it can, we're done.
  for _, name in ipairs(template_names) do
    local t = GSC.fn.resolve_template_name(name)
    if t then
      gsdebug("Looking for token %s in template %s", token, name)
      local f = t[token]
      if f then
        return f(text)
      end
    else
      gsdebug("Unable to resolve template name: %s", name)
    end
  end
  -- Nothing found. Log and return.
  gsdebug("*** Unable to resolve token [%s]. Looked here: %s", token, template_names)
  return nil
end

-- Returns a single Latex string generated from the many (token, text) pairs.
-- See tex_eval_single() for a descrption of these.
-- In the event of a token not having an apparent implementation, a message to
-- this effect is inserted in the list. That means it will make its way through
-- Latex to the PDF.
-- If the input list is nil, return an empty table.
-- TODO improve efficiency and code clarity by preparing a list of templates
-- (from the template names) and passing that to a new function tex_eval_single_1,
-- or similar.
GSC.fn.tex_eval_sequential = function(list, template_names)
  if list == nil then
    return ""
  end
  typecheck(list, 'table')
  typecheck(template_names, 'table')
  local result = {}
  for _,x in ipairs(list) do
    local token, text = table.unpack(x)
    local latex = GSC.fn.tex_eval_single(token, text, template_names)
    latex = latex or F([[\textcolor{red}{\textbf{Unable to resolve token `%s'}} \par]], token)
    table.insert(result, latex)
  end
  return table.concat(result, "\n")
end

-- Here is the implementation of this very important function.
-- Steps:
--  * determine the content template (e.g. WS1)
--  * retrieve the template object from our template store
--  * call template:init() to perform initialisation
--  * call template:expand() to generate the Latex
--  * tex.print() it
GSC.fn.emit_tex = function()
  -- 0. Respect !IGNORE pragma.
  if GSC.pragmas.ignore then
    return
  end

  gsdebug()
  gsdebug("*** emit_tex() called ***")
  gsdebug([[>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> GSC.content]])
  gsdebug(pretty_print(GSC.content))
  gsdebug([[<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<]])
  gsdebug()

  -- 1. Respect draft mode.
  if GSC.api.get_draft_mode() and not GSC.pragmas.draft then
    P([[\textcolor{Mulberry}{Draft mode: skipping title \textbf{%s}}]], GSC.content.META.TITLE)
    -- TODO implement GSC.fn.get_title() because we can't really guarantee that META.TITLE
    -- exists. A fallback could be the template name, which must exist. In fact, the template
    -- name should probably always be included in the "title", and maybe a better name than
    -- "title" (for the immediate purpose here) can be found.
    gsdebug("~~~ Skipping content because of DRAFT mode ~~~")
    gsdebug()
    return
  end

  -- 2. Get the template name
  local ok, template_name = pcall(function() return GSC.content.META.TEMPLATE end)
  if not ok then
    P([[{\Large\textcolor{red}{No template specified!!}}]])
    return
  end

  -- 3. Turn that into a template
  local t = GSC.fn.template_table()
  local f = t[template_name]
  if f == nil then
    P([[{\Large\textcolor{red}{Unable to resolve template `%s'}}]], template_name)
    return
  end

  -- 4. Call init() to perform any necessary initialisation (e.g. set counters)
  if f.init then f.init() end

  -- 5. Call expand() to get the latex code
  if f.expand == nil then
    error(F("Template '%s' needs to include an expand() function", template_name))
  end
  local latex = f.expand()
  if type(latex) ~= 'string' then
    error(F("Template '%s' expand() needs to return a string (of Latex code)", template_name))
  end

  gsdebug(" - logging the generated Latex")
  gsdebug()
  gsdebug(latex)

  -- 6. Send the code to Latex
  for line in magiclines(latex) do
    P(line)
  end
end


-- [[                                    ]]
-- [[             utilities              ]]
-- [[                                    ]]

-- Parse the META.SPACING spec (e.g. INDEFINT 8pt :: TEXT 12pt :: CHALLENGE 20pt) and
-- return the spacing value associated with the given token, or nil.
GSC.util.get_spacing_spec = function(token)
  local x = GSC.content.META.SPACING
  if not x then return nil end
  local bits = split(x, ' :: ')
  for _,y in ipairs(bits) do
    local _token, _spc = table.unpack(split(y))
    if _token == token then
      return _spc
    end
  end
  return nil
end

-- When a token cannot be resolved, or suchlike, we insert an error into the PDF rather
-- than stop the show. This function helps to format that error.
GSC.util.tex_error = function(msg)
  return F([[{\color{red}\bfseries %s}]], msg)
end

-- A very simple function, only useful because it saves repeating code in several places.
GSC.util.heading_and_text_indent = function (heading, text)
 return F([[\HeadingIndent{%s}{%s}]], heading, text)
end

GSC.util.heading_and_text_inline = function (heading, text)
  return F([[\HeadingInline{%s}{%s} \par]], heading, text)
end

-- 1 -> 'A', 2 -> 'B' etc.
GSC.util.upcase_letter = function (n)
  return string.char(64+n)
end


-- [[                                    ]]
-- [[              testing               ]]
-- [[                                    ]]

GSC.test.tex_eval_single_test = function()
  local output = GSC.fn.tex_eval_single('Q', '$3+4=$', { 'Basic' })
  assert(output == nil)
  output = GSC.fn.tex_eval_single('Q', '$3+4=$', { 'Questions' })
  assert(output == [[\QuestionQ{$3+4=$} \par]])
  output = GSC.fn.tex_eval_single('Q', '$3+4=$', { 'Questions', 'Basic' })
  assert(output == [[\QuestionQ{$3+4=$} \par]])
  output = GSC.fn.tex_eval_single('Q', '$3+4=$', { 'Basic', 'Questions' })
  assert(output == [[\QuestionQ{$3+4=$} \par]])
end

GSC.test.tex_eval_sequential_test = function()
  local input = { {'Q','$9-6=$'}, {'QQ','Hello'}, {'VSPACE','5cm'}, {'XYZ', 'xyz'}}
  local expected = table.concat({
    [[\QuestionQ{$9-6=$} \par]],
    [[\QuestionQQ{Hello} \par]],
    [[\vspace{5cm} \par]],
    [[\textcolor{red}{\textbf{Unable to resolve token `XYZ'}} \par]],
  }, "\n")
  local output = GSC.fn.tex_eval_sequential(input, { 'Questions', 'Basic' })
  local equal = (output == expected)
  assert(equal, 'Failed test of tex_eval_sequential')
end

GSC.test.all_tests = function()
  local t = GSC.test
  t.tex_eval_single_test()
  t.tex_eval_sequential_test()
end

-- GSC.test.all_tests()
