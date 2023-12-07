--
-- We act on the global table `lbt` and populate its subtable `lbt.api`.
--

local assert_string = pl.utils.assert_string
local assert_bool = function(n,x) pl.utils.assert_arg(n,x,'boolean') end

-- The Latex environment `lbt` has three parts: beginning, middle, end.
--  * At the beginning, the current "content" needs to be cleared to make
--    way for new content.
--  * In the middle, the author's text needs to be processed into structured
--    content.
--  * At the end, the structured content needs to be turned into Latex and
--    emitted into the stream.
-- These three stages have API support in the functions below.
--  * clear_content    * process    * emit_tex

lbt.api.clear_content = function()
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.api.process = function(text)
  assert_string(1,text)
  lbt.fn.populate_content_and_pragmas(text)
end

lbt.api.emit_tex = function()
  lbt.fn.emit_tex()
end

-- Draft mode allows for a piece of content to be skipped in the PDF,
-- speeding compilation and allowing for greater focus in writing.
-- It is similar to Latex \importonly.
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
