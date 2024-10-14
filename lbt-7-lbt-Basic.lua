-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format

local f = {}   -- functions
local a = {}   -- number of arguments
local m = {}   -- macros
local o = pl.List()  -- options

-- --------------------------------------------------------------------
-- environment_name('align', true)  --> 'align*'
-- environment_name('align', false) --> 'align'
local environment_name = function (base, star)
  return F('%s%s', base, star and '*' or '')
end
-- --------------------------------------------------------------------

-- Text (TEXT puts a paragraph after, TEXT* does not)

-- f.TEXT = function(text) return F([[%s \par]], text) end
-- f["TEXT*"] = function(text) return F([[%s]], text) end

local textparagraphs = function (args, starting_index)
  return args:slice(starting_index,-1):concat([[ \par ]])
end

o:append'TEXT*.vspace=0pt'
a["TEXT*"] = '1+'
f["TEXT*"] = function (n, args, o)
  local paragraphs = textparagraphs(args,1)
  if o.vspace == '0pt' then
    return paragraphs
  else
    return F('\\vspace{%s}\n%s', o.vspace, paragraphs)
  end
end

o:append'TEXT.vspace=0pt'
a.TEXT = '1+'
f.TEXT = function (n, args, o)
  local paragraphs = textparagraphs(args,1)
  if o.vspace == '0pt' then
    return F([[%s \par]], paragraphs)
  else
    return F('\\vspace{%s}\n%s \\par', o.vspace, paragraphs)
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
f.NEWCOMMAND = function(n, args)
  local name, number, implementation = table.unpack(args)
  if number == '0' then
    return F([[\newcommand{\%s}{%s}]], name, implementation)
  elseif #number == 1 and number >= '1' and number <= '9' then
    return F([[\newcommand{\%s}[%s]{%s}]], name, number, implementation)
  else
    return { error = "Invalid argument for parameter 'number' in NEWCOMMAND" }
  end
end

-- Paragraph

a.PARAGRAPH = '2+'
f.PARAGRAPH = function(n, args, o)
  return F([[\paragraph{%s}{%s} \par]], args[1], textparagraphs(args,2))
end

a['PARAGRAPH*'] = 2
f['PARAGRAPH*'] = function(n, args, o)
  return F([[\paragraph{%s}{%s}]], args[1], textparagraphs(args,2))
end

-- tcolorbox (simple use only; will have to add options)
a.BOX = '1+'
f.BOX = function(n, args, o)
  local content = args:concat([[ \par \medskip ]])
  local result = F([[
\begin{tcolorbox}
  %s
\end{tcolorbox}
  ]], content)
  return result
end

-- Itemize and enumerate

o:append 'ITEMIZE.notop = false, ITEMIZE.compact = false, ITEMIZE.sep=nil'
a.ITEMIZE = '1+'
f.ITEMIZE = function (n, args, o, k)
  if args[1]:startswith('[') then
    IX('old-style ITEMIZE')
  end
  -- customisations come from options 'notop/compact' and keyword 'spec'
  local spec = pl.List()
  if k.spec then spec:append(k.spec) end
  if o.notop then
    spec:append('topsep=0pt')
  end
  if o.compact then
    spec:append('topsep=-\\parskip, itemsep=0pt')
  end
  spec = spec:concat(', ')
  -- build result
  local prepend_item = function(text) return [[\item ]] .. text end
  local items = args:map(prepend_item):join("\n  ")
  local result = F([[
\begin{itemize}[%s]
  %s
\end{itemize}
  ]], spec, items)
  return result
end

-- TODO: Factor out code from ITEMIZE and ENUMERATE.
-- TODO: Support custom environments via .o env=...
o:append 'ENUMERATE.notop = false, ENUMERATE.compact = false'
a.ENUMERATE = '1+'
f.ENUMERATE = function (n, args, o, k)
  if args[1]:startswith('[') then
    IX('old-style ENUMERATE')
  end
  -- customisations come from options 'notop/compact' and keyword 'spec'
  local spec = pl.List()
  if k.spec then spec:append(k.spec) end
  if o.notop then
    spec:append('topsep=0pt')
  end
  if o.compact then
    spec:append('topsep=-\\parskip, itemsep=0pt')
  end
  spec = spec:concat(', ')
  -- build result
  local prepend_item = function(text) return [[\item ]] .. text end
  local items = args:map(prepend_item):join("\n  ")
  local result = F([[
\begin{enumerate}[%s]
  %s
\end{enumerate}
  ]], spec, items)
  return result
end

-- Headings H1 H2 H3
--   (plain design, specific templates can overwrite)
a.H1 = 1
f.H1 = function(n, args)
  return F([[
%% Heading 1
\par \vspace{1.5em}
{\Large %s}
  ]], args[1])
end

a.H2 = 1
f.H2 = function(n, args)
  return F([[
%% Heading 2
\par \vspace{1em}
{\large %s}
  ]], args[1])
end

a.H3 = 1
f.H3 = function(n, args)
  return F([[
%% Heading 3
\par \vspace{0.7em}
\textbf{%s}
  ]], args[1])
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

a.INDENT = 2
f.INDENT = function (n, args)
  local x     = lbt.util.comma_split(args[1])
  local left  = x[1]
  local right = x[2] or ''
  local text  = args[2]
  return F([[
    \begin{adjustwidth}{%s}{%s}
      %s
    \end{adjustwidth}
  ]], left, right, text)
end

-- Math environments like ALIGN(*) -- probably need to add others.

-- TODO think about the design of align. Could it take one argument per line?
-- Could it take some options, like spreadlines?
-- For example
--   ALIGN*   opt: spreadlines=1em      [or some other signifier for options]
--    » :: a^2 + b^2 &= c^2
--    » :: E &= mc^2
--    » :: F = ma

local align_impl = function (star, args, o)
  local format_contents = function(text)
    if o.leftindent then
      return args:concat([[&& \\]] .. '\n')
    else
      return args:concat([[ \\]] .. '\n')
    end
  end
  local t = pl.List()
  if o.vspace == -1 then
    t:append [[\vspace{-\parskip}]]
  elseif o.vspace then
    t:append [[\vspace{!VSPACE!}]]
  end
  if o.spreadlines then
    t:append [[\begin{spreadlines}{!SPREADLINES!}]]
  end
  t:append [[\begin{!ENVNAME!}]]
  t:append '!CONTENTS!'
  t:append [[\end{!ENVNAME!}]]
  if o.spreadlines then
    t:append [[\end{spreadlines}]]
  end
  t.values = {
    VSPACE      = o.vspace,
    SPREADLINES = o.spreadlines,
    ENVNAME     = environment_name(o.leftindent and 'flalign' or 'align', star),
    CONTENTS    = format_contents()
  }
  local x = lbt.util.string_template_expand(t)
  return lbt.util.leftindent(x, o)
end

o:append 'ALIGN.spreadlines = nil, ALIGN.leftindent = nil, ALIGN.vspace = -1'
a.ALIGN = '1+'
f.ALIGN = function(n, args, o)
  return align_impl(false, args, o)
end

o:append 'ALIGN*.spreadlines = nil, ALIGN*.leftindent = nil, ALIGN*.vspace = -1'
a['ALIGN*'] = '1+'
f['ALIGN*'] = function(n, args, o)
  return align_impl(true, args, o)
end

a.EQUATION = 1
f.EQUATION = function (n, args)
  return F([[
\begin{equation}
  %s
\end{equation}
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

-- FIGURE* for no caption

local function figure_options(options_str)
  local extract = function(list, x)
    local i = list:index(x)
    if i == nil then
      return nil
    else
      list:remove(i)
      return x
    end
  end
  if options_str == nil then
    return { valid = true, centering = true }
  end
  local opts = lbt.util.comma_split(options_str)
  local centering, position = true, nil
  if extract(opts, 'nocentre') or extract(opts, 'nocenter') or extract(opts, 'nocentering') then
    centering = false
  end
  if opts:len() == 0 then
    return { valid = true, centering = centering }
  elseif opts:len() == 1 then
    return { valid = true, centering = centering, position = opts[1] }
  else
    return { valid = false }
  end
end

-- Options: bhtp, nocentre (or nocentering)
-- Arguments: [options] :: content :: caption
-- Centering is applied by default; specify nocenter if you want to.
a.FIGURE = '2-3'
f.FIGURE = function (n, args, o)
  local options, args = lbt.util.extract_option_argument(args)
  local opts = { centering = true }
  local opts = figure_options(options)
  local content, caption = table.unpack(args)
  if opts.valid == false then
    return { error = F("Invalid figure options: '%s'", options)}
  else
    local position_str, centering_str = '', ''
    if opts.centering then centering_str = [[\centering]] end
    if opts.position  then position_str  = F('[%s]', opts.position) end
    local template = [[
      \begin{figure}%s
        %s
        %s
        \caption{%s}
      \end{figure}
    ]]
    return F(template, position_str, centering_str, content, caption)
  end
end


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

a.VERBATIM = 1
f.VERBATIM = function (n, args)
  local lines = args[1]
  return F([[
    \begin{verbatim}
      %s
    \end{verbatim}
  ]], lines)
end

-- return ok, (data|errormsg)
local table_data_separator = function (filename)
  if filename:endswith('.tsv') then
    return true, '\t'
  else if filename:endswith('.csv') then
      return true, ' '
    else
      return false, F('Unknown file type: %s', filename)
    end
  end
end

-- return stat, data, errormsg
--   stat = 0 for no data to load, 1 for successful data load, 2 for error
local table_load_data_from_file = function (kw)
  if kw.datafile then
    local data = pl.List()
    local ok, sep = table_data_separator(kw.datafile)
    if not ok then
      return 2, nil, sep   -- sep is the errormsg
    end
    for line in io.lines(kw.datafile) do
      data:append(lbt.util.split(line, sep))
    end
    return 1, data, nil
  else
    return 0, nil, nil
  end
end

-- named arguments: template, instruction, data
-- return ok (true or false)
-- side-effect: append lines to template
local table_insert_rows_from_data = function (namedargs)
  local x = namedargs
  local range = lbt.parser.parse_table_datarows(x.instruction)
  if range then
    local A, B = table.unpack(range)
    local i = A
    while i <= B and i <= x.data:len() do
      local row = x.data[i]
      local line = row:concat(' & ') .. [[ \\]]
      x.template:append(line)
      i = i + 1
    end
    return true
  else
    return false   -- couldn't parse the datarows spec
  end
end

-- Table (using tabularray)
a.TABLE = '1+'
o:append 'TABLE.center = false, TABLE.centre = false, TABLE.leftindent = false'
o:append 'TABLE.fontsize = nil'
o:append 'TABLE.float = false, TABLE.position = htbp'
f.TABLE = function(n, args, o, kw)
  -- t is our template list where we accumulate our result
  -- Note: we do not include a table environment. That is applied (if o.float) once
  -- everything, including centering and other formatting, is done. See bottom of function.
  local t = pl.List()
  -- extract the table spec (there must be one)
  local spec = kw.spec
  if not spec then return { error = 'No table spec provided' } end
  -- load data from file, if necessary
  local stat, data, errormsg = table_load_data_from_file(kw)
  if stat == 2 then return { error = errormsg } end
  -- If it is a floating table, apply the (optional) caption and label.
  if o.float then
    if kw.caption then t:append [[\caption{!CAPTION!}]] end
    if kw.label   then t:append [[\label{!LABEL!}]] end
  end
  -- If it is not a floating table, there might still be a caption, which
  -- we manually format (with no table number).
  if not o.float then
    if kw.caption then
      t:append ''
      t:append [[{\small\textbf{Table}\enspace !CAPTION!}]]
      t:append [[\smallskip]]
      t:append ''
    end
  end
  -- beginning of tblr environment
  t:append [[\begin{tblr}{!SPEC!}]]
  -- contents of table (positional arguments)
  for line in args:iter() do
    if line:startswith('@datarows') then
      local ok = table_insert_rows_from_data {
        template = t, instruction = line, data = data
      }
      if not ok then return { error = 'Invalid datarows spec: ' .. line } end
    elseif pl.stringx.lfind(line, [[\hline]]) then
      -- we do not put a \\ on this line
      t:append(line)
    else
      t:append(line .. [[ \\]])
    end
  end
  -- end of tblr environment
  t:append [[\end{tblr}]]
  -- expand the template and handle o.centre or o.leftindent
  t.values = {
    SPEC = spec,
    CAPTION = kw.caption,
    LABEL = kw.label,
  }
  local result = lbt.util.string_template_expand(t)
  result = lbt.util.apply_horizontal_formatting(result, o)
  result = lbt.util.apply_style_formatting(result, o)
  -- if it is a floating table, wrap all this in a table environment
  if o.float then
    result = lbt.util.wrap_environment {
      environment = 'table',
      content     = result,
      bracket_arg = o.position
    }
  end
  return result
end


-- TWOPANEL .o ratio=2:3, align=bt :: \DiagramOne :: ◊DiagramOneText
a.TWOPANEL = 2
o:append 'TWOPANEL.ratio = 1:1, TWOPANEL.align = tt'
f.TWOPANEL = function(n, args, o)
  local ratio = lbt.parser.parse_ratio(2, o.ratio)
  local align = lbt.parser.parse_align(2, o.align)
  local w1 = ratio[1] / (ratio[1] + ratio[2])
  local w2 = ratio[2] / (ratio[1] + ratio[2])
  local a1, a2 = table.unpack(align)
  local c1, c2 = table.unpack(args)
  local template = [[
      \begin{minipage}[%s]{%s\textwidth}
        %s
      \end{minipage}%%
      \begin{minipage}[%s]{%s\textwidth}
        %s
      \end{minipage}
    ]]
  return F(template, a1, w1, c1, a2, w2, c2)
  -- TODO: use string template
end

-- Example:
--   SIDEBYSIDE* 0.6 :: 0.4 :: t :: c :: ◊A :: ◊B
-- Note: this will be replaced with a more generic TWOPANE in Basic with a
-- better syntax.
a['SIDEBYSIDE*'] = 6
f['SIDEBYSIDE*'] = function (n, args, sr)
  -- width 1 and 2, content 1 and 2
  local w1, w2, j1, j2, c1, c2 = table.unpack(args)
  local template = [[
      \begin{minipage}[%s]{%s\textwidth}
        \vspace{0pt}
        %s
      \end{minipage}\hfill
      \begin{minipage}[%s]{%s\textwidth}
        %s
      \end{minipage}
    ]]
  return F(template, j1, w1, c1, j2, w2, c2)
end

-- +---------------------------------------+
-- | Macros                                |
-- +---------------------------------------+

-- e.g. \diagram{align=centre,width=0.6,media/cat-image-014.png}
-- e.g. \diagram{align=left,indent=3cm,width=11cm,media/cat-image-015.png}
m.diagram = function(text)
end

-- +---------------------------------------+
-- | Then we call `lbt.api.make_template`. |
-- +---------------------------------------+

return {
  name      = 'lbt.Basic',
  desc      = 'Fundamental Latex macros for everyday use (built in to lbt)',
  sources   = {},
  init      = lbt.api.default_template_init,
  expand    = lbt.api.default_template_expand,
  functions = f,
  arguments = a,
  default_options = o,
}
