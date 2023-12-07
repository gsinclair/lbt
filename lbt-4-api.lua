--
-- We act on the global table `lbt` and populate its subtable `lbt.api`.
--

-- The Latex environment `lbt` has three parts: beginning, middle, end.
--  * At the beginning, the current "content" needs to be cleared to make
--    way for new content.
--  * In the middle, the author's text needs to be processed into structured
--    content.
--  * At the end, the structured content needs to be turned into Latex and
--    emitted into the stream.
-- These three stages have API support in the functions below.
--  * clear_content    * process    * emit_tex

local assert_string = pl.utils.assert_string
local assert_bool = function(n,x) pl.utils.assert_arg(n,x,'boolean') end
local assert_table = function(n,x) pl.utils.assert_arg(n,x,'table') end

lbt.api.reset_state_for_new_expansion = function()
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.api.populate_content = function(text)
  assert_string(1,text)
  lbt.fn.populate_content_and_pragmas(text)
end

lbt.api.emit_tex = function()
  lbt.fn.emit_tex()
end

-- Called directly in a Lua block from Latex code.
--   TODO consider making draft mode a package option.
-- If true, populate_content will short-circuit to (nearly) a no-op unless the
-- first line of content is DRAFT.
-- This will speed up compilation.
lbt.api.set_draft_mode = function(x)
  assert_bool(1,x)
  lbt.const.draft_mode = x
end

lbt.api.get_draft_mode = function()
  return lbt.const.draft_mode
end

-- Debug mode allows for extra debug information to be generated only
-- where it is needed.
lbt.api.set_debug_mode = function(x)
  assert_bool(1,x)
  lbt.const.debug_mode = x
end

lbt.api.get_debug_mode = function()
  return lbt.const.debug_mode
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
  -- TODO implement!
end

lbt.api.make_template = function(tbl)
  assert_table(1,tbl)
  assert_string(1,tbl.name)
  -- ...
  lbt.system.templates[tbl.name] = tbl
  -- TODO complete verifications, and check we are not overwriting another template
end
