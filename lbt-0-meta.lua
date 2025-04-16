
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
-- Also a 'debuglog' file, which is really just for absolutely targeted and temporary
-- debugging.
--

local logfile = io.open("lbt.log", "w")

local _debuglogfile = nil
local debuglogfile = function()
  if _debuglogfile then
    return _debuglogfile
  else
    _debuglogfile = io.open('lbt.debuglog', 'w')
    return _debuglogfile
  end
end

local channel_name = { [0] = 'ANN',  [1] = 'ERROR', [2] = 'WARN',
                       [3] = 'INFO', [4] = 'TRACE' }

lbt.log = function (channel, format, ...)
  if lbt.api.query_log_channels(channel) then
    local message
    if ... == nil then
      message = format
    else
      message = F(format, ...)
    end
    local name = channel_name[channel] or channel
    local line = F('[#%-10s] %s\n', name, message)
    logfile:write(line)
    logfile:flush()
  end
end

lbt.debuglog = function(format, ...)
  local line = F(format, ...)
  debuglogfile():write(line)
  debuglogfile():write('\n')
  debuglogfile():flush()
end

-- Some essential functions that are defined here so they don't have to be
-- local to just about every file.

lbt.pp            = function(x) return (x == {} and '{}' or pl.pretty.write(x)) end
lbt.assert_string = pl.utils.assert_string
lbt.assert_bool   = function(n,x) pl.utils.assert_arg(n,x,'boolean') end
lbt.assert_table  = function(n,x) pl.utils.assert_arg(n,x,'table') end

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
    print(lbt.pp(text2))
  else
    print("\n\n\n\n ↓ ↓ ↓ ↓ <INSPECT>\n\n")
    print(lbt.pp(text1))
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

