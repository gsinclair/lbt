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

----- -- The purpose of DEF is to define a "register" for immediate use. The name
----- -- should be like mathA or something that definitely won't conflict with an
----- -- existing name. No need for a clear name because it is for immediate use.
----- f.DEF = function (text)
-----   local args = split(text, '::')
-----   if #args == 2 then
-----     local name, content = table.unpack(args)
-----     -- Remove $ at beginning and end
-----     if content:sub(1,1) == '$' and content:sub(-1,-1) == '$' then
-----       content = content:sub(2, -2)
-----     end
-----     local template = [[
-----       \providecommand{\%s}{}
-----       \renewcommand{\%s}{%s}
-----     ]]
-----     return F(template, name, name, content)
-----   else
-----     return GSC.util.tex_error('DEF requires two arguments separated by ::')
-----   end
----- end

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

----- f.HEADING = function(text)
-----   local args = split(text, '::')
-----   if #args == 2 then
-----     return GSC.util.heading_and_text_indent(args[1], args[2])
-----   else
-----     return GSC.util.tex_error('HEADING requires two arguments separated by ::')
-----   end
----- end
----- 
----- f.HEADING_INLINE = function(text)
-----   local args = split(text, '::')
-----   if #args == 2 then
-----     return GSC.util.heading_and_text_inline(args[1], args[2])
-----   else
-----     return GSC.util.tex_error('HEADING_INLINE requires two arguments separated by ::')
-----   end
----- end
----- 
----- f.SIDEBYSIDE = function (text)
-----   local args = split(text, '::')
-----   if #args == 2 then
-----     return F([[\TwoMinipagesSideBySide{%s}{%s}]], args[1], args[2])
-----   else
-----     return GSC.util.tex_error('SIDEBYSIDE requires two arguments separated by ::')
-----   end
----- end
----- 
----- f['SIDEBYSIDE*'] = function (text)
-----   local args = split(text, '::')
-----   if #args == 6 then
-----     -- width 1 and 2, content 1 and 2
-----     local w1, w2, j1, j2, c1, c2 = table.unpack(args)
-----     local template = [[
-----       \begin{minipage}[%s]{%s\textwidth}
-----         \vspace{0pt}
-----         %s
-----       \end{minipage}\hfill
-----       \begin{minipage}[%s]{%s\textwidth}
-----         %s
-----       \end{minipage}
-----     ]]
-----     return F(template, j1, w1, c1, j2, w2, c2)
-----   else
-----     return GSC.util.tex_error('SIDEBYSIDE requires four arguments -- w1, w2, just1, just2, cont1, cont2 -- separated by ::')
-----   end
----- end
----- 
----- f.FIGURE = function (text)
-----   local args = split(text, '::')
-----   if #args == 2 then
-----     local content, caption = table.unpack(args)
-----     local template = [[
-----       \begin{figure}[bhpt]
-----         \centering
-----         %s
-----         \caption{%s}
-----       \end{figure}
-----     ]]
-----     return F(template, content, caption)
-----   else
-----     return GSC.util.tex_error('FIGURE requires two arguments separated by ::')
-----   end
----- end
----- 
----- f.RIGHT = function (text)
-----   return F([[
-----     \begin{flushright}
-----       %s
-----     \end{flushright}
-----   ]], text)
----- end

-- +---------------------------------------+
-- | Then we call `lbt.api.make_template`. |
-- +---------------------------------------+

return {
  name      = 'Basic',
  desc      = 'Fundamental Latex macros for everyday use (built in to lbt)',
  sources   = {},
  init      = lbt.api.default_template_init(),
  expand    = lbt.api.default_template_expand(),
  functions = f
}

