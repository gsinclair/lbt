-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format
local pp = pl.pretty.write

local f = {}   -- functions
local a = {}   -- number of arguments

-- Text (TEXT puts a paragraph after, TEXT* does not)

-- f.TEXT = function(text) return F([[%s \par]], text) end
-- f["TEXT*"] = function(text) return F([[%s]], text) end

a["TEXT*"] = '1-2'
f["TEXT*"] = function (n, args)
  if n == 1 then
    return 'ok', args[1]
  elseif n == 2 then
    return 'ok', F([[\vspace{%s} %s]], args[1], args[2])
  end
end

a.TEXT = '1-2'
f.TEXT = function (n, args)
  local stat, x = f["TEXT*"](n, args)
  if stat == 'ok' then
    return 'ok', x .. [[ \par]]
  else
    return stat, x
  end
end

-- General Latex command, and some specific ones.

-- CMD vfill        --> \vfill
-- CMD tabto 20pt   --> \tabto{20pt}     [can have more arguments]
a.CMD = '1+'
f.CMD = function(n, args)
  local command = F([[\%s]], args[1])
  local arguments = args:slice(2,-1):map(lbt.util.wrap_braces):join()
  return 'ok', command..arguments  
end

a.VSPACE = 1
f.VSPACE = lbt.util.latex_cmd('vspace', 1, 'par')

a.VFILL = 0
f.VFILL = lbt.util.latex_cmd('vfill', 0)

a.CLEARPAGE = 0
f.CLEARPAGE = lbt.util.latex_cmd('clearpage', 0)

a.VSTRETCH = 1
f.VSTRETCH = function(n, args)
  return F([[\vspace{\stretch{%s}}]], args[1])
end

a.COMMENT = '0+'
f.COMMENT = function(n, args)
  return ""
end

-- Begin and end environment     TODO allow for environment options

a.BEGIN = '1+'
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

a.END = 1
f.END = function(arg)
  return F([[\end{%s}]], arg)
end

-- \newcommand

a.NEWCOMMAND = 3
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

a.ITEMIZE = '1+'
f.ITEMIZE = function (n, args)
  local options, args = lbt.util.extract_option_argument(args)
  local prepend_item = function(text) return [[\item ]] .. text end
  local items = args:map(prepend_item):join("\n  ")
  local result = F([[
\begin{itemize}[%s]
  %s
\end{itemize}
  ]], options or '', items)
  return 'ok', result
end

a.ENUMERATE = '1+'
f.ENUMERATE = function (n, args)
  local options, args = lbt.util.extract_option_argument(args)
  local prepend_item = function(text) return [[\item ]] .. text end
  local items = args:map(prepend_item):join("\n  ")
  local result = F([[
\begin{enumerate}[%s]
  %s
\end{enumerate}
  ]], options or '', items)
  return 'ok', result
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
  name      = 'lbt.Basic',
  desc      = 'Fundamental Latex macros for everyday use (built in to lbt)',
  sources   = {},
  init      = lbt.api.default_template_init(),
  expand    = lbt.api.default_template_expand(),
  functions = f,
  arguments = a
}

