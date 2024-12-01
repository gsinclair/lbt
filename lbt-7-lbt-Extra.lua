-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format

local f = {}   -- functions
local a = {}   -- number of arguments
local m = {}   -- macros
local o = pl.List()  -- options

a.MINTED = 1
o:append 'MINTED.lang = none, MINTED.env = none, MINTED.number = false'
f.MINTED = function(n, args, o)
  local a,b,c
  if o.lang == 'none' then
    a = [[\begin{Verbatim}]]
  else
    a = F([[
\begin{minted}
[
  baselinestretch=1.2,
  bgcolor=Gray!15,
  fontsize=\small,
  xleftmargin=3em,
  curlyquotes=false,
  linenos,
  autogobble,
  python3,
  stripnl
]{%s}]], o.lang)
  end
  b = lbt.util.straighten_quotes(args[1])
  if o.lang == 'none' then
    c = [[\end{Verbatim}]]
  else
    c = [[\end{minted}]]
  end
  return lbt.util.join_lines(a,b,c)
end

-- +---------------------------------------+
-- | Macros                                |
-- +---------------------------------------+

-- +---------------------------------------+
-- | Then we call `lbt.api.make_template`. |
-- +---------------------------------------+

return {
  name      = 'lbt.Extra',
  desc      = 'An addendum to lbt.Basic to contain MINTED',
  sources   = {},
  init      = nil,
  expand    = lbt.api.default_template_expander(),
  functions = f,
  arguments = a,
  default_options = o,
}

