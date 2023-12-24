
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
--
-- Usage: INSPECT("Template name", tn)     [optional pre-text]
-- Usage: INSPECT(tn)
--
-- Use INSPECTX instead to exit the program afterwards.
local INSPECT_impl = function(text1, text2)
  if text2 then
    print("\n\n\n\n ↓ ↓ ↓ ↓ <INSPECT>   " .. text1 .. "\n\n")
    print(pp(text2))
  else
    print("\n\n\n\n ↓ ↓ ↓ ↓ <INSPECT>\n\n")
    print(pp(text1))
  end
end
INSPECT = function(text1, text2)
  INSPECT_impl(text1, text2)
  print("\n\n ↑ ↑ ↑ ↑ </INSPECT>\n\n")
end
INSPECTX = function(text1, text2)
  INSPECT_impl(text1, text2)
  print("\n\n ↑ ↑ ↑ ↑ </INSPECT> (exiting)")
  os.exit()
end

I = INSPECT
IX = INSPECTX
