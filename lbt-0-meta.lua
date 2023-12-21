
---It is good form to provide some background information about this Lua
---module.

if not modules then
  modules = {}
end
modules['lbt'] = {
  version = '0.1',
  comment = 'lua-based-tables (lbt)',
  author = 'Gavin Sinclair',
  copyright = 'Gavin Sinclair',
  license = 'The LaTeX Project Public License Version 1.3c 2008-05-04',
}

--
-- We set up logging and debugging functions here because they are "meta"
-- to the package.
--

local logfile = io.open("lbt.log", "w")
local dbgfile = io.open("lbt.dbg", "w")

lbt.log = function (text, level)
  local level = level or 1
  logfile:write(string.format([[L%d » %s]].."\n", level, text))
  logfile:flush()
end

lbt.dbg = function (format, ...)
  -- TODO make this sensitive to both system debug and per-instance debug
  --      (or something)
  if not lbt.api.get_debug_mode() then
    return
  end
  local line = nil
  if type(format) == 'string' then
    line = string.format(format, ...)
  else
    line = pl.pretty.write(format)
  end
  dbgfile:write(line.."\n")
  dbgfile:flush()
end

local pp = pl.pretty.write

-- A useful function during periods of active development.
-- Comment out when not in use, to avoid polluting the global namespace.
DEBUG = function(text)
  print("\n\n\n\n\n\n - - - - DEBUG")
  print(pp(text))
  print("\n\n - - - - EXITING NOW")
  os.exit()
end

