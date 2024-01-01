--
-- We act on the global table `lbt` and populate its subtable `lbt.api`.
--

local F = string.format
local pp = pl.pretty.write

local assert_string = pl.utils.assert_string
local assert_bool = function(n,x) pl.utils.assert_arg(n,x,'boolean') end
local assert_table = function(n,x) pl.utils.assert_arg(n,x,'table') end

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
--  * lbt.fn.template_object_or_nil(name)    _or_error
--  * lbt.fn.template_path_or_nil(name)      _or_error
lbt.api.add_template_directory = function (dir)
  dir = lbt.fn.expand_directory(dir)
  if not pl.path.isdir(dir) then
    lbt.err.E208_nonexistent_template_dir(dir)
  end
  lbt.log(F("Adding template directory: %s", dir))
  local paths = pl.dir.getfiles(dir, "*.lua")
  for path in paths:iter() do
    lbt.log(F(" * %s", pl.path.basename(path)))
    local ok, x = pcall(dofile, path)
    if ok then
      local template_details = x
      lbt.fn.register_template(template_details, path)
    else
      local err_details = x
      lbt.err.E213_failed_template_load(path, err_details)
    end
  end
  lbt.dbg("Added template directory <%s>", dir)
  lbt.fn.template_names_to_dbgfile()
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
end

lbt.api.author_content_emit_latex = function()
  lbt.dbg("lbt.api.author_content_emit_latex()")
  lbt.dbg("  Current contents of lbt.const.author_content pasted below")
  lbt.dbg("")
  lbt.dbg("<<<")
  lbt.dbg(pl.pretty.write(lbt.const.author_content))
  lbt.dbg(">>>")
  lbt.dbg("")
  local c  = lbt.const.author_content
  local pc = lbt.fn.parsed_content(c)
  lbt.fn.validate_parsed_content(pc)
  local l  = lbt.fn.latex_expansion(pc)
  tex.print(l)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- If true, populate_content will short-circuit to (nearly) a no-op unless the
-- content contains a `!DRAFT` pragma. This will speed up compilation.
lbt.api.set_draft_mode = function(x)
  assert_bool(1,x)
  lbt.system.draft_mode = x
end

lbt.api.get_draft_mode = function()
  return lbt.system.draft_mode
end

-- Debug mode allows for extra debug information to be generated only
-- where it is needed.
lbt.api.set_debug_mode = function(x)
  assert_bool(1,x)
  lbt.system.debug_mode = x
end

lbt.api.get_debug_mode = function()
  return lbt.system.debug_mode
end

-- Counters are auto-created, so this will always return a value. The initial will be zero.
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

-- This is slightly hacky because this general lbt code shouldn't have knowledge of
-- specific counters. An alternative could be a table that specifies counters to be
-- reset upon a new chapter, or part, or section, or...
-- That alternative is not worth pursuing at the moment.
-- TODO pursue this!
lbt.api.reset_chapter_counters = function()
  lbt.api.counter_reset('worksheet')
  lbt.api.counter_reset('quiz')
end

-- TODO Reconsider whether chapter abbreviation is a legitimate concept for the package.
--      A better alternative might be arbitrary data that can be set outside of an expansion,
--      like \lbtStore{chapterAbbreviation=Integration by parts}
lbt.api.set_chapter_abbreviation = function (x)
  lbt.var.chapter_abbreviation = x
end

lbt.api.get_chapter_abbreviation = function ()
  return lbt.var.chapter_abbreviation
end

-- Template initialisation is a chance to set required state like counters.
-- Therefore, the _default_ template initialisation is a function that does nothing.
lbt.api.default_template_init = function()
  return function ()
    -- do nothing
  end
end

-- Template expansion acts on a parsed content (plus sources and styles) and
-- produces a string of Latex code.
--
-- A template that is a structural will provide its own expand() function to
-- lay out the page as needed. A template that is content-based has no need
-- to do this, so it can lean on this default implementation.
--
-- The default expansion is to run the contents of BODY through
-- `lbt.fn.parsed_content_to_latex_multi`. That means this expansion is
-- assuming that the author content includes a '+BODY' somewhere. We raise an
-- error if it does not exist.
lbt.api.default_template_expand = function()
  return function (pc, tr, sr)
    -- abbreviations for: parsed content, token resolver, style resolver
    lbt.dbg('Inside default_template_expand for template <%s>', lbt.fn.pc.template_name(pc))
    lbt.dbg('  - argument sr == %s', pp(sr))
    local body = lbt.fn.pc.content_list(pc, 'BODY')
    lbt.dbg(' * BODY has <%d> items to expand', body:len())
    if body == nil then
      lbt.err.E301_default_expand_failed_no_body()
    end
    return lbt.fn.parsed_content_to_latex_multi(body, tr, sr)
  end
end

-- TODO lbt.api.expand_content_list(key)
-- So that template authors can call it on BODY or on other things.
-- Then default_template_expand can use this.


-- lbt.api.style(key)
-- 
-- A template has styles built in to it. For example, in a Questions template
-- the default vspace before a question might be 12pt. And so if the template
-- object is `t` then we would have `t.styles['vspace'] == '12pt'`.
-- 
-- A template has styles built in to it. For example, in a Questions template
-- we might have:
--   
--   a.Q = 1
--   s.Q = { vspace = '12pt', color = 'RoyalBlue' }
--   f.Q = function(n, args)
--     local vsp = lbt.api.style('Q.vspace')
--     local col = lbt.api.style('Q.color')
--     local q   = lbt.api.counter_inc('q')
--     return F([[{\color{%s}\bfseries Question~%d \enspace %s \par}]],
--              vsp, col, q, args[1])
--   end
--
-- This demonstrates _setting_ the styles with `s.Q = { ... }` and _getting_
-- them with `lbt.api.style(...)`. Note that the function for getting them
-- is intentionally short because it will be called upon often. It can be
-- localised within a template file via `local style = lbt.api.style` if
-- desired.
--
-- So what happens here? Well, when the template is registered, the style
-- information is a dictionary:
--
--   t.styles == { Q = { vspace = '12pt', ...}, ...}
--
-- Upon registration this is collapsed so that we have:
--
--   t.styles == { 'Q.vspace' = '12pt', 'Q.color' = 'RoaylBlue',
--                 'MC.alphabet' = 'Roman', ... }
--
-- Another style for the `MC` token was included to show how many tokens
-- live side-by-side in this collapsed style dictionary.
--
-- But those are the styles for only one template. An expansion typically
-- involves several templates, so to resolve a style we (in principle) have to
-- look in several places. Further, there can be document-wide overrides and
-- expansion-wide overrides, as seen in the example below.
--
--   \lbtStyle{Q.vspace 12pt :: MC.alphabet :: arabic }
--
--   \begin{lbt}
--     @META
--       TEMPLATE    Exam
--       STYLE       Q.vspace 30pt :: Q.color gray :: MC.alphabet roman
--     +BODY
--       TEXT  You have 30 minutes.
--       Q  Evaluate:
--       QQ $2+2$
--       QQ $\exp(i\pi)$
--   \end{lbt}
--
-- To resolve styles at expansion time, there are three good options:
--
--  * Form a consolidated dictionary of all styles, respecting overrides.
--    Store this globally or pass it around.
--
--  * Look in all required places, in order, until the style is found,
--    and then cache the result for future lookups. This means some information
--    needs to be global.
--
--  * Create a style resolver and pass that around. This keeps information
--    private in a closure (like we do with a token resolver) but it means
--    token functions having a third parameter.
--
-- We take the third option. I initially baulked at token functions taking
-- another parameter, but have now gone down that route because Lua allows you
-- to write only as many parameters as you need. It's loose but convenient.
-- For example, in a Questions template:
--
--   f.Q = function(n, args, s)
--     local vsp, col = s.get('Q.vspace Q.color')
--     ...
--   end
--
--   f.MC = function(n, args)
--     ...
--   end
--
-- In particular, look at the way style access is implemented, using one long
-- string to look up many values. This helps keep token functions concise.
--
-- Amazingly, I have written documentation for a function where the design
-- has changed from the top of the function to the bottom. In fact, the
-- function no longer exists!! Anyway, it is staying here for this commit
-- and will be removed later, becuase the text above is a useful basis for
-- documentation.
--
lbt.api.style = function (key)
  -- TODO remove!
end

lbt.api.add_styles = function (text)
  local map = lbt.fn.style_string_to_map(text)
  lbt.log('Document-wide styles are being updated:')
  lbt.log(pp(map))
  lbt.system.document_wide_styles:update(map)
  return nil
end
