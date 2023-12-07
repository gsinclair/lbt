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
  end
  lbt.system.templates_loaded = true
  return lbt.system.templates
end

-- ...
