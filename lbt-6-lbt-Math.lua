
-- +---------------------------------------+
-- | lbt.Math                              |
-- |                                       |
-- | Macros for integrals and vectors      |
-- +---------------------------------------+

local F = string.format
local pp = pl.pretty.write

local f = {}   -- functions
local a = {}   -- number of arguments
local m = {}   -- macros

-- myvec is a flexible vector renderer. Here are examples of the arguments it
-- can handle. Arguments are space-separated. Remember they are text.
--
--   a                 default italic undertilde
--   bold a
--   tilde a
--
--   AB                italic overarrow (no other option)
--
--   2 -5              column vector
--   1 6 -4
--   row 3 8 1         can force row
--   col 3 8 1         but column is the default

m.myvec = function (text)
  local args = lbt.util.comma_split(text)
  if args:len() ~= 1 or not args[1]:match('^%l$') then
    return lbt.util.latex_macro_error('Math.myvec: single lower-case argument only (for now)')
  end
  return F([[\ensuremath{\underaccent{\tilde}{%s}}]], args[1])
  -- The rest is old implementation for later.
  -- if args[1] == "row" then
  --   -- We render the contents as a row vector (same as a point).
  --   table.remove(args, 1)
  --   local innards = table.concat(args, ',')
  --   local output = [[\ensuremath{\left( %s \right)}]]
  --   tex.sprint(F(output, innards))
  -- elseif #args == 1 then
  --   local arg = args[1]
  --   if #arg == 1 then
  --     -- We render the pronumeral (say, v) as a vector with an undertilde.
  --     local output = [[\ensuremath{\underaccent{\tilde}{%s}}]]
  --     tex.sprint(F(output, arg))
  --   elseif #arg == 2 then
  --     -- We render the interval (say, AB) as a vector with an overarrow.
  --     local output = [[\ensuremath{\vv{%s}}]]
  --     tex.sprint(F(output, arg))
  --   end
  -- else
  --   -- We render a column vector with the (presumably) two or three values
  --   local contents = table.concat(args, [[ \\ ]])
  --   local output = [[\ensuremath{\begin{pmatrix}%s\end{pmatrix}}]]
  --   tex.sprint(F(output, contents))
  -- end
end

return {
  name      = 'lbt.Math',
  desc      = 'Specific support for mathematical typesetting',
  sources   = {},
  init      = nil,
  expand    = nil,
  functions = f,
  arguments = a,
  macros    = m,
}

