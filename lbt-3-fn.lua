--
-- We act on the global table `lbt` and populate its subtable `lbt.fn`.
--

-- alias for pretty-printing a table
local pp = pl.pretty.write


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

