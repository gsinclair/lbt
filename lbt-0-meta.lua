
local F = string.format

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
-- We set up a log file and log function here because they are "meta" to the
-- package.
--

local logfile = io.open("lbt.log", "w")

local channel_subscribed = function (ch)
  local x = lbt.system.log_channels
  return ch == 0 or x:contains(ch) or x:contains('all')
end

local channel_name = { [0] = 'ANN',  [1] = 'ERROR', [2] = 'WARN',
                       [3] = 'INFO', [4] = 'TRACE' }

lbt.log = function (channel, format, ...)
  assert(lbt.system.log_channels:len() >= 0)
  if channel_subscribed(channel) then
    local message = F(format, ...)
    local name = channel_name[channel] or channel
    local line = F('[#%-10s] %s\n', name, message)
    logfile:write(line)
    logfile:flush()
  end
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
