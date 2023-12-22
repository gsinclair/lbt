-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format

local f = {}

-- Text (TEXT puts a paragraph after, TEXT* does not)

f.TEXT = function(text) return F([[%s \par]], text) end
f["TEXT*"] = function(text) return F([[%s]], text) end

-- General Latex command, and some specific ones.

f.CMD = function(x) return F([[\%s]], x) end

f.VSPACE = lbt.util.latex_cmd_par_1("vspace")
f.VSTRETCH = function(x) return F([[\vspace{\stretch{%s}}]], x) end
f.VFILL = lbt.util.latex_cmd("vfill")
f.CLEARPAGE = lbt.util.latex_cmd("clearpage")

f.COMMENT = function(_) return "" end

-- Begin and end environment     TODO allow for environment options

f.BEGIN = function(text)
  local args = split(text)
  if #args == 1 then
    return F([[\begin{%s}]], args[1])
  elseif #args == 2 then
    return F([[\begin{%s}{%s}]], args[1], args[2])
  elseif #args == 3 then
    return F([[\begin{%s}{%s}{%s}]], args[1], args[2], args[3])
  else
    return F([[{\color{red} ENV needs 1-3 arguments, not '%s'}]], text)
  end
end

f.END = function(arg)
  return F([[\end{%s}]], arg)
end

-- \newcommand

f.NEWCOMMAND = function(text)
  local args = split(text, '::')
  if #args ~= 3 then
    return GSC.utils.tex_error("Three arguments required for newcommand: name, number, implementation")
  else
    local name, number, implementation = table.unpack(args)
    if number == '0' then
      return F([[\newcommand{\%s}{%s}]], name, implementation)
    elseif #number == 1 and number >= '1' and number <= '9' then
      return F([[\newcommand{\%s}[%d]{%s}]], name, number, implementation)
    else
      return GSC.util.tex_error("Invalid argument for parameter 'number' in NEWCOMMAND")
    end
  end
end

-- Itemize and enumerate

f.ITEMIZE = function(text)
  local args = split(text, '::')
  local options = ""
  local content = ""
  if #args == 1 then
    content = args[1]
  elseif #args == 2 then
    options = args[1]
    content = args[2]
  end
  local result = F([[
    \begin{itemize}[%s]
      %s
    \end{itemize}
  ]], options, content)
  return result
end

f.ENUMERATE = function(text)
  local args = split(text, '::')
  local options = ""
  local content = ""
  if #args == 1 then
    content = args[1]
  elseif #args == 2 then
    options = args[1]
    content = args[2]
  end
  local result = F([[
    \begin{enumerate}[%s]
      %s
    \end{enumerate}
  ]], options, content)
  return result
end

-- +-------------------------------------------+
-- | Then we call `lbt.api.register_template`. |
-- +-------------------------------------------+

lbt.api.register_template {
  name      = 'Basic',
  sources   = {},
  init      = lbt.api.default_template_init(),
  expand    = lbt.api.default_template_expand(),
  functions = f
}

