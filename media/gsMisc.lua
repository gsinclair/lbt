
local gsMisc = {}

-- Graph with integral area shaded.
--
-- Example argument text:
--   x=-2:5 y=-3:3 f=x*sin(x**2) bounds=0:2 color=blue!60
--
-- Example output:
--
--   \begin{tikzpicture}[scale=0.8]
--     \tkzInit[xmin=-2,xmax=5,xstep=1,ymin=-3,ymax=3,ystep=1]
--     \tkzGrid
--     \tkzAxeXY
--     \tkzFct[domain= -2:5]{x*sin(x**2)}
--     \tkzDrawArea[color=blue!60, domain = 0:2]
--   \end{tikzpicture}
--
gsMisc.graphWithIntegral = function(argtext)
  local graph_error = function(x)
    return F([[{\color{red} Invalid graph argtext: %s}]], x)
  end
  local args = {}
  for k,v in string.gmatch(argtext, "(%S+)=(%S+)") do
    args[k] = v
  end
  args.scale = args.scale or '0.8'
  args.xstep = args.xstep or '1'
  args.ystep = args.ystep or '1'
  local xmin, xmax = string.match(args.x, "(%S+):(%S+)")
  local ymin, ymax = string.match(args.y, "(%S+):(%S+)")
  if not (xmin and xmax and ymin and ymax) then return graph_error(argtext) end
  local template = [[
    \begin{tikzpicture}[scale=%s]
      \tkzInit[xmin=%s,xmax=%s,xstep=%s,ymin=%s,ymax=%s,ystep=%s]
      \tkzGrid
      \tkzAxeXY
      \tkzFct[line width=0.6pt, domain=%s]{%s}
      \tkzDrawArea[color=%s, domain=%s]
    \end{tikzpicture}
  ]]
  local a = args
  if not (a.f and a.color and a.bounds) then return graph_error(argtext) end
  return F(template, a.scale, xmin, xmax, a.xstep, ymin, ymax, a.ystep, a.x, a.f, a.color, a.bounds)
end

-- Graph
--
-- Example argument text:
--   x=-2:5 y=-3:3 f=x*sin(x**2)
--
-- Based on the code of graphWithIntegral. Some refactoring would be good, but I'll wait
-- until there are more use cases (e.g. multiple graphs on one plane).
--
gsMisc.graph = function(argtext)
  local graph_error = function(x)
    return F([[{\color{red} Invalid graph argtext: %s}]], x)
  end
  local args = {}
  for k,v in string.gmatch(argtext, "(%S+)=(%S+)") do
    args[k] = v
  end
  args.scale = args.scale or '0.8'
  args.xstep = args.xstep or '1'
  args.ystep = args.ystep or '1'
  local xmin, xmax = string.match(args.x, "(%S+):(%S+)")
  local ymin, ymax = string.match(args.y, "(%S+):(%S+)")
  if not (xmin and xmax and ymin and ymax and args.f) then return graph_error(argtext) end
  local template = [[
    \begin{tikzpicture}[scale=%s]
      \tkzInit[xmin=%s,xmax=%s,xstep=%s,ymin=%s,ymax=%s,ystep=%s]
      \tkzGrid
      \tkzAxeXY
      \tkzFct[line width=0.6pt, domain=%s]{%s}
    \end{tikzpicture}
  ]]
  local a = args
  local fafd = F(template, a.scale, xmin, xmax, a.xstep, ymin, ymax, a.ystep, a.x, a.f)
  gsdebug(fafd)
  return fafd
end

return gsMisc
