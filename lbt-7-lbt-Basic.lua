-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand

local f = {}   -- functions
local a = {}   -- number of arguments
local m = {}   -- macros
-- local o = pl.List()  -- options
local op = {}
local kw = {}

local impl = {}

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

-- TEXT creates one or more paragraphs.
-- TEXT* suppresses the \par that would normally be put at the end.
a.TEXT = '1+'
op.TEXT = { starred = false, par = true }
f.TEXT = function (n, args, o)
  local paragraphs = textparagraphs(args,1)
  if o.starred then
    o:_set_local('par', false)
  end
  return paragraphs
end

-- LATEX passes things straight through to Latex. It's exactly the same as
-- TEXT* (but only takes one argument) but it's useful to have a clearer name
-- for the purpose.
--   Generally use it with .v, as in
--     LATEX .v <<
--       ...
--     >>
a.LATEX = 1
f.LATEX = function(_, args)
  return args[1]
end

-- General Latex command, and some specific ones.

-- CMD vfill        --> \vfill
-- CMD tabto 20pt   --> \tabto{20pt}                               [can have an argument]
-- CMD newlist :: shoppinglist :: itemize :: 1                     [or many arguments]
-- CMD setlist :: [shoppinglist] :: label=\ding{168}, left=2em     [recognises square brackets]
a.CMD = '1+'
f.CMD = function(n, args)
  local command = F([[\%s]], args[1])
  lbt.debuglograw('CMD')
  lbt.debuglograw(lbt.pp(args))
  local arguments = args:slice(2,-1):map(lbt.util.wrap_braces_or_brackets):join()
  lbt.debuglograw('CMD - arguments joined')
  lbt.debuglograw(arguments)
  return command..arguments
end

a.VSPACE = 1
op.VSPACE = { starred = false }
f.VSPACE = function(n, args, o)
  if o.starred then
    return F([[\vspace*{%s}]], args[1])
  else
    return F([[\vspace{%s}]], args[1])
  end
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

-- Part, chapter, section, subsection, subsubsection, paragraph, subparagraph

local document_section = function(name, title, o, kw)
  local starred = o:_has_local_key('starred') and o.starred
  return T {
    [[\!NAME!!STAR!{!TITLE!} !LABEL!]],
    values = {
      NAME = name,
      TITLE = title,
      STAR = starred and '*' or '',
      LABEL = kw.label and F([[\label{%s}]], kw.label) or ''
    }
  }
end

a.PART = '1'
f.PART = function(n, args, o, kw)
  return document_section('part', args[1], o, kw)
end

a.CHAPTER = '1'
op.CHAPTER = { starred = false }
f.CHAPTER = function(n, args, o, kw)
  return document_section('chapter', args[1], o, kw)
end

a.SECTION = '1'
op.SECTION = { starred = false }
f.SECTION = function(n, args, o, kw)
  return document_section('section', args[1], o, kw)
end

a.SUBSECTION = '1'
op.SUBSECTION = { starred = false }
f.SUBSECTION = function(n, args, o, kw)
  return document_section('subsection', args[1], o, kw)
end

a.SUBSUBSECTION = '1'
op.SUBSUBSECTION = { starred = false }
f.SUBSUBSECTION = function(n, args, o, kw)
  return document_section('subsubsection', args[1], o, kw)
end

a.PARAGRAPH = '2+'
op.PARAGRAPH = { starred = false, par = true }
f.PARAGRAPH = function(n, args, o, kw)
  if o.starred then o:_set_local('par', false) end
  return T {
    [[\paragraph{!TITLE!} !LABEL!]],
    '!TEXT!',
    values = {
      TITLE = args[1],
      LABEL = kw.label and F([[\label{%s}]], kw.label) or '',
      TEXT  = textparagraphs(args,2),
    }
  }
end

a.SUBPARAGRAPH = '2+'
op.SUBPARAGRAPH = { starred = false, par = true }
f.SUBPARAGRAPH = function(n, args, o, kw)
  if o.starred then o:_set_local('par', false) end
  return T {
    [[\subparagraph{!TITLE!} !LABEL!]],
    '!TEXT!',
    values = {
      TITLE = args[1],
      LABEL = kw.label and F([[\label{%s}]], kw.label) or '',
      TEXT  = textparagraphs(args,2),
    }
  }
end

-- tcolorbox (simple use only; will have to add options)
a.BOX = '1+'
op.BOX = { lbt = false }  -- NOTE: experimental feature
f.BOX = function(n, args, o)
  local content
  if o.lbt then
    content = lbt.util.lbt_commands_text_into_latex(args[1])
  else
    content = args:concat([[ \par \medskip ]])
  end
  local result = F([[
\begin{tcolorbox}
  %s
\end{tcolorbox}
  ]], content)
  return result
end

-- Itemize and enumerate

op.ITEMIZE = { notop = false, compact = false, sep = 1, env = 'nil' }
;           -- ^^^^^ NOTE: noX is now implemented; shouldn't need explicit notop
a.ITEMIZE = '1+'
f.ITEMIZE = function (n, args, o, k)
  if args[1]:startswith('[') then
    IX('old-style ITEMIZE')
  end
  -- customisations come from options 'notop/compact' and keyword 'spec'
  local spec = pl.List()
  if k.spec then spec:append(k.spec) end
  if o.compact then
    spec:append('topsep=-\\parskip, itemsep=0pt')
  end
  if o.sep then
    spec:append(F([[itemsep=%s\itemsep, topsep=%s\topsep]], o.sep, o.sep))
  end
  if o.notop then
    spec:append('topsep=0pt')
  end
  spec = spec:concat(', ')
  -- build result
  local prepend_item = function(text) return [[\item ]] .. text end
  local items = args:map(prepend_item):join("\n  ")
  return T {
    [[\begin{!ENV!}[!OPTIONS!] ]],
    items,
    [[\end{!ENV!} ]],
    values = {
      ENV = o.env or 'itemize',
      OPTIONS = spec
    }
  }
end

-- TODO: Factor out code from ITEMIZE and ENUMERATE.
op.ENUMERATE = { env = 'nil', notop = false, compact = false }
;             -- ^^^^^ NOTE: noX is now implemented; shouldn't need explicit notop
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
  return T {
    [[\begin{!ENV!}[!OPTIONS!] ]],
    items,
    [[\end{!ENV!} ]],
    values = {
      ENV = o.env or 'enumerate',
      OPTIONS = spec
    }
  }
end

-- LIST: a generalisation of ITEMIZE and ENUMERATE that uses them flexibly, including sublists.
-- Example:
--   LIST .o markers = * (a) i.    -- bullets for top level, then (a) (b) (c), then (i) (ii) (iii)
--   :: Cats
--   :: * Black
--   :: * White
--   :: Dogs
--   :: * Large
--   :: * * Bloodhound
--   :: * * Labrador
--   :: * Small
--   :: * * Toy poodle
--
-- It takes any opargs that ITEMIZE or ENUMERATE do.
-- TODO: Find a way to accept any opargs. Or perhaps 'update' some opargs like a dictionary.

local itemize_markers = {
  ['*'] = [[\textbullet]],
  cdot  = [[$\cdot$]],
  star  = [[$\star$]],
  bigstar  = [[$\bigstar$]],
  ast   = [[$\ast$]],
  circ  = [[$\circ$]],
  blackstar = '★',            -- replace with dingbat?
  whitestar = '☆',
  hand = [[\ding{43}]],
  arrow = [[\ding{213}]],
  check = [[\ding{51}]],
  cross = [[\ding{55}]],
  snowflake = [[\ding{101}]],
  blacksquare = [[\ding{110}]],
  todo = [[\ding{111}]],
}

local enumerate_markers = {
  circnumsans  = { env = 'dingautolist', argument = '192'},
  circnumserif = { env = 'dingautolist', argument = '172'},
  circnum      = { env = 'dingautolist', argument = '192'}
}

a.LIST = '1+'
op.LIST = { markers = '* * * *' }
f.LIST = function(n, args, o)
  local groups = lbt.util.analyse_indented_items(args, 'grouped')
  local markers = lbt.util.space_split(o.markers)
  local result = pl.List()
  local additem  = function(text)  result:append(F([[\item %s]], text)) end
  local additems = function(items) for x in items:iter() do additem(x) end end
  -- local addbegin = function(env, mr) result:append(F([[\begin{%s}[%s] ]], env, mr)) end
  local addbegin = function(t)
    if t.argument then result:append(F([[\begin{%s}{%s}]], t.env, t.argument)) end
    if t.option   then result:append(F([[\begin{%s}[%s] ]], t.env, t.option)) end
  end
  -- local addend   = function(env)   result:append(F([[\end{%s}]], env)) end
  local addend   = function(t) result:append(F([[\end{%s}]], t.env)) end
  local environment_for_marker = function(mr)
    if itemize_markers[mr] then
      return { env = 'itemize', option = itemize_markers[mr] }
    end
    if mr:isdigit() and tonumber(mr) >= 31 then
      return { env = 'itemize', option = F([[\ding{%s}]], mr) }
    end
    if enumerate_markers[mr] then
      return enumerate_markers[mr]
    end
    return { env = 'enumerate', option = mr }
  end
  local environment_for_level = function(n)
    return environment_for_marker(markers[n+1])
  end
  local L = -1              -- current nested level
  local stack = pl.List()   -- environments that have to be ended
  for group in groups:iter() do
    local level, items = table.unpack(group)
    if level == L + 1 then
      local t = environment_for_level(level)
      stack:append(t)
      addbegin(t)
      additems(items)
      L = level
    elseif level < L then
      while level < L do
        addend(stack:pop())
        L = L - 1
      end
      additems(items)
    end
  end
  while stack:len() > 0 do
    addend(stack:pop())
  end
  return result:join('\n')
end

-- Headings H1 H2 H3
--   (plain design, specific templates can overwrite)
a.H1 = 1
f.H1 = function(n, args)
  return F([[
%% Heading 1
\par \vspace{1.5em}
{\noindent\Large %s}
  ]], args[1])
end

a.H2 = 1
f.H2 = function(n, args)
  return F([[
%% Heading 2
\par \vspace{1em}
{\noindent\large %s}
  ]], args[1])
end

a.H3 = 1
f.H3 = function(n, args)
  return F([[
%% Heading 3
\par \vspace{0.7em}
\noindent\textbf{%s}
  ]], args[1])
end

-- Columns (because why not? And because multicols doesn't let you do 1 col)
a.COLUMNS = 1
op.COLUMNS = { starred = false }
f.COLUMNS = function(n, args, o)
  local ncols = tonumber(args[1])
  if ncols == nil or n < 1 then
    return { error = 'COLUMNS argument must be a positive integer' }
  elseif ncols == 1 then
    lbt.api.data_set('Basic.COLUMNS.ncols', 1)
    return ''
  else
    lbt.api.data_set('Basic.COLUMNS.ncols', ncols)
    local starred = ''
    if o.starred then starred = '*' end
    lbt.api.data_set('Basic.COLUMNS.starred', starred)
    return F([[\begin{multicols%s}{%d}]], starred, ncols)
  end
end

a.ENDCOLUMNS = 0
f.ENDCOLUMNS = function (n, args)
  local ncols = lbt.api.data_get('Basic.COLUMNS.ncols')
  local starred = lbt.api.data_get('Basic.COLUMNS.starred')
  lbt.api.data_delete('Basic.COLUMNS.ncols')
  lbt.api.data_delete('Basic.COLUMNS.starred')
  if ncols == nil then
    return { error = 'ENDCOLUMNS without COLUMNS' }
  elseif ncols == 1 then
    return ''
  else
    return F([[\end{multicols%s}]], starred)
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
-- XXX: This is old-school code that needs to be updated, pronto!
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
op.VERBATIM = { env = 'nil', breaklines = true }
f.VERBATIM = function (n, args, o)
  local lines = args[1]:rstrip()
  local env = 'Verbatim'
  if o.env then env = o.env end
  local spec = ''
  if not o.env and o.breaklines then spec = '[breaklines]' end  -- XXX: temporary hack
  return F([[
    \begin{%s}%s
      %s
    \end{%s}
  ]], env, spec, lines, env)
end

----- TABLE and supporting code

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

a.TABLE = '1+'
op.TABLE = { center = false, centre = false, leftindent = false, fontsize = 'nil',
             float = false, position = 'htbp', par = true }
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
    elseif impl.table_row_is_a_rule(line) then
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
    result = lbt.util.wrap_environment { result, 'table', oparg = o.position }
  end
  return result
end

impl.table_row_is_a_rule = function(line)
  local fn = function(x) return pl.stringx.lfind(line, '\\'..x) end
  return fn('hline') or fn('toprule') or fn('midrule') or fn('bottomrule') or fn('cmidrule')
end

----- /TABLE

-- PDFINCLUDE .o setdirectory :: media/Vectors
-- PDFINCLUDE .o pages = 7-13 :: Chapter 4
a.PDFINCLUDE = '1'
op.PDFINCLUDE = { pages = 'nil', setdirectory = false }
f.PDFINCLUDE = function(n, args, o)
  if o.setdirectory then
    lbt.api.data_set('lbt.Basic.pdfinclude.directory', args[1])
    return "{}"
  end
  local directory = lbt.api.data_get('lbt.Basic.pdfinclude.directory', '.')
  local path = F('%s/%s', directory, args[1])
  if not path:endswith('.pdf') then path = path .. '.pdf' end
  local pages = o.pages or '-'
  return F([[\includepdf[pages={%s}]{%s}]], pages, path)
end

a.INCLUDELBT = 1
f.INCLUDELBT = function(_, args)
  local path = args[1]
  local content = pl.file.read(path)
  if content == nil then
    lbt.err.E002_general("Attempt to INCLUDELBT failed. Can't read the file: %s", path)
  end
  return lbt.util.lbt_commands_text_into_latex(content)
end

-- TWOPANEL .o ratio=2:3, align=bt :: \DiagramOne :: ◊DiagramOneText
a.TWOPANEL = 2
op.TWOPANEL = { ratio = '1:1', align = 'tt' }
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
  init      = nil,
  expand    = lbt.api.default_template_expander(),
  functions = f,
  posargs = a,
  opargs = op,
}
