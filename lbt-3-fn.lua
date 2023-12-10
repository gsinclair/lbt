--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

lbt.fn.impl = {
  assert_nonempty = function(list)
    if list:len() == 0 then
      error("Attempt to continue previous line, but there is no previous line")
    end
    return list
  end
}

local P = lbt.util.tex_print_formatted

-- alias for pretty-printing a table
local pp = pl.pretty.write

--------------------------------------------------------------------------------
-- Author content:
--  * author_content_clear   * author_content_append   * author_content_process
--------------------------------------------------------------------------------

lbt.fn.author_content_clear = function()
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.fn.author_content_append = function(line)
  line_list = lbt.var.author_content
  line = line:strip()
  if line:sub(1,2) == "»" then
    -- Continuation of previous line
    prev_line = lbt.fn.impl.assert_nonempty(line_list):pop()
    line = prev_line .. " " .. line:sub(3,-1)
  end
  lbt.var.author_content:append(line)
end

-- This is called at the end of `lbt` environment. There are no arguments
-- because the author content has been captured line by line in `lbt.var.content_buffer`.
lbt.fn.author_content_process = function()
  local lineno = 1
  for line in lbt.var.author_content:iter() do
    lbt.dbg("PROCESS: %s", line)
    pl.utils.printf("PROCESS: %s", line)
    P([[Line %d: <%s> \\]].."\n", lineno, line:strip())
    lineno = lineno + 1
  end
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

lbt.fn.resolve_template_name = function(name)
  return lbt.fn.template_table()[name]
end

