-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format

local f = {}   -- functions
local a = {}   -- number of arguments

-- Text (TEXT puts a paragraph after, TEXT* does not)

-- f.TEXT = function(text) return F([[%s \par]], text) end
-- f["TEXT*"] = function(text) return F([[%s]], text) end

a["TEXT*"] = '1-2'
f["TEXT*"] = function (n, args)
  if n == 1 then
    return args[1]
  elseif n == 2 then
    return F([[\vspace{%s} %s]], args[1], args[2])
  end
end

a.TEXT = '1-2'
f.TEXT = function (n, args)
  if n == 1 then
    return F([[%s \par]], args[1])
  elseif n == 2 then
    return F([[\vspace{%s} %s \par]], args[1], args[2])
  end
end

-- General Latex command, and some specific ones.

-- CMD vfill        --> \vfill
-- CMD tabto 20pt   --> \tabto{20pt}     [can have more arguments]
a.CMD = '1+'
f.CMD = function(n, args)
  local command = F([[\%s]], args[1])
  local arguments = args:slice(2,-1):map(lbt.util.wrap_braces):join()
  return command..arguments  
end

a.VSPACE = 1
f.VSPACE = function(n, args)
  return F([[\vspace{%s}]], args[1])
end

a.VFILL = 0
f.VFILL = function(n, args)
  return F([[\vfill{}]])
end

a.CLEARPAGE = 0
f.CLEARPAGE = function(n, args)
  return F([[\clearpage{}]])
end

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
f.BEGIN = function(n, args)
  local command = F([[\begin{%s}]], args[1])
  if n > 1 then
    local arguments = args:slice(2,-1):map(lbt.util.wrap_braces):join()
    return command..arguments
  else
    return command
  end
end

a.END = 1
f.END = function(n, args)
  return F([[\end{%s}]], args[1])
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
  return result
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
  return result
end

-- Columns (because why not? And because multicols doesn't let you do 1 col)
a.COLUMNS = 1
f.COLUMNS = function(n, args)
  local ncols = tonumber(args[1])
  if ncols == nil or n < 1 then
    return { error = 'COLUMNS argument must be a positive integer' }
  elseif ncols == 1 then
    lbt.api.data_set('Basic.ncols', 1)
    return ''
  else
    lbt.api.data_set('Basic.ncols', ncols)
    return F([[\begin{multicols}{%d}]], ncols)
  end
end

a.ENDCOLUMNS = 0
f.ENDCOLUMNS = function (n, args)
  local ncols = lbt.api.data_get('Basic.ncols')
  lbt.api.data_delete('Basic.ncols')
  if ncols == nil then
    return { error = 'ENDCOLUMNS without COLUMNS' }
  elseif ncols == 1 then
    return ''
  else
    return [[\end{multicols}]]
  end
end

-- Math environments like ALIGN(*) -- probably need to add others.

-- TODO think about the design of align. Could it take one argument per line?
-- Could it take some options, like spreadlines?
-- For example
--   ALIGN*   opt: spreadlines=1em      [or some other signifier for options]
--    » :: a^2 + b^2 &= c^2
--    » :: E &= mc^2
--    » :: F = ma

a.ALIGN = 1
f.ALIGN = function(n, args)
  return F([[
\begin{align}
  %s
\end{align}
  ]], args[1])
end

a['ALIGN*'] = 1
f['ALIGN*'] = function(n, args)
  return F([[
\begin{align*}
  %s
\end{align*}
  ]], args[1])
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

a.FLUSHLEFT = 1
f.FLUSHLEFT = function (n, args)
  return F([[
    \begin{flushleft}
      %s
    \end{flushleft}
  ]], args[1])
end

a.FLUSHRIGHT = 1
f.FLUSHRIGHT = function (n, args)
  return F([[
    \begin{flushright}
      %s
    \end{flushright}
  ]], args[1])
end

a.CENTER = 1
f.CENTER = function (n, args)
  return F([[
    \begin{centering}
      %s
    \end{centering}
  ]], args[1])
end

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

