--
-- We act on the global table `lbt` and populate its subtable `lbt.api`.
--

local F = string.format

local assert_string = pl.utils.assert_string
local assert_bool = function(n,x) pl.utils.assert_arg(n,x,'boolean') end
local assert_table = function(n,x) pl.utils.assert_arg(n,x,'table') end


-- When starting up, we need to survey the filesystem to see what templates
-- are available. We make a shallow register like
--   { "Basic"       = { path = ..., template = ... },
--     "Questions"   = { path = ..., template = nil },
--     "Tables"      = { path = ..., template = nil },
--     "contrib.WS0" = { path = ..., template = nil },
--     ... }
-- It contains paths only at this point. The actual template objects will be
-- filled in when they are needed. The exception is Basic, which is always
-- available.
--
-- The templates can be built-in (Basic), contrib (WS0), or user-supplied
-- (Questions). These come from different paths.
--
-- Built-in and contrib templates live in the lbt distribution directory.
-- User-supplied templates live on the user's computer. The user needs to
-- call \lbtTemplateDirectory{...} one or more times so that we know where
-- to look.
--
-- FIXME this means we can't call initialise_template_register in the .sty
-- file, because the user has not built the path yet.
--
-- TODO delete this code
lbt.api.initialise_template_register = function ()
  local templates = lbt.system.templates
  if pl.tablex.size(tempates) > 0 then
    lbt.log("WARN: Attempt to re-initialise template register ignored")
    return
  end
end

-- Put each lua file in the directory into the template register,
-- just with the path for now.
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
      lbt.fn.register_template(template_details)
    else
      local err_details = x
      lbt.err.E213_failed_template_load(path, err_details)
    end
  end
  lbt.dbg("Added template directory <%s>; here is the current register...", dir)
  lbt.dbg(lbt.system.template_register)
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

-- Template expansion acts on a single parameter (`text`) and returns a string of Latex.
-- The default expansion is to run the contents of BODY through `lbt.fn.` 
lbt.api.default_template_expand = function()
  return function (pc, sources, styles)
    -- TODO implement!
  end
end
