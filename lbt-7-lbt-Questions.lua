-- +----------------------------------------+
-- | Template: lbt.Questions                |
-- |                                        |
-- | Purpose: Questions, hints, answers for |
-- |          worksheets, exams, ...        |
-- +----------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand

local f = {}
local a = {}
local o = pl.List()

-- Support function to lay out horizontal subquestions or ---------------------
-- multiple-choice options horizontally in fixed columns  ---------------------
-- or using hfill -------------------------------------------------------------

local function errormsg1(cmd)
  return F([[First argument to %s must specify the number of
 columns (e.g. \Verb|[ncols=3, vspace=20pt]| or set \Verb|hpack=hfill|)]], cmd)
end

local function errormsg2(cmd)
  return F([[In %s, don't specify \Verb|ncols| and \Verb|hpack=hfill| together]], cmd)
end

local function get_options_ncols_vspace_hpack(command, args)
  local options, args = lbt.util.extract_option_argument(args)
  if options == nil then
    return { 'error', errormsg1(command) }
  end
  options = lbt.util.parse_options(options)
  if options == nil then
    return { 'error', errormsg1(command) }
  end
  if options.hpack == 'hfill' and options.ncols then
    return { 'error', errormsg2(command) }
  end
  return { 'ok', options, args }
end

-- The backbone of both column-based and hfill-based subquestions.
-- Iterates through each text and processes it using the typesetter functions.
-- The typesetter functions are provided by either layout_qq_columns or layout_qq_hfill.
local function layout_qq(texts, typesetter_body, typesetter_end, opts)
  local result = pl.List()
  local add = function(line, ...) result:append(F(line, ...)) end
  add([[\begin{adjustwidth}{%s}{}]], opts.leftindent or '0pt')
  add('\n')
  for i = 1,#texts do
    local qtext = texts[i]
    local qnum  = lbt.api.counter_inc(opts.counter)
    local label = lbt.util.number_in_alphabet(qnum, opts.alphabet)
    add(typesetter_body(i, label, qtext))
  end
  add(typesetter_end())
  add('\n')
  add([[\end{adjustwidth}]])
  return result:concat('')
end

local function layout_qq_columns(texts, opts)
  local ncols      = opts.ncols
  local colwidth   = F([[%f\textwidth]], 1 / opts.ncols)
  local labelwidth = opts.labelwidth or '1.5em'
  local vspace     = opts.vspace or '6pt'
  local colorspec  = ''
  if opts.labelcolor then
    colorspec = F([[\color{%s}]], opts.labelcolor)
  end
  --
  local typesetter_body = function (i, label, qtext)
    local labelset = F([[\parbox{%s}{%s(%s)}]], labelwidth, colorspec, label)
    local columnset = F([[\parbox{%s}{%s\mbox{%s}}]], colwidth, labelset, qtext)
    if i % ncols == 0 or i == #texts then
      return F([[%s\\[%s]{}]], columnset, vspace)
    else
      return columnset
    end
  end
  local typesetter_end = function () return '' end
  --
  return layout_qq(texts, typesetter_body, typesetter_end, opts)
end

local function layout_qq_hfill(texts, opts)
  local labelwidth = opts.labelwidth or '1.5em'
  local colorspec = ''
  if opts.labelcolor then
    colorspec = F([[\color{%s}]], opts.labelcolor)
  end
  --
  local typesetter_body = function (i, label, qtext)
    local labelset = F([[\parbox{%s}{%s(%s)}]], labelwidth, colorspec, label)
    local textset  = F([[%s\hfill\,]], qtext)
    return labelset .. textset
  end
  local typesetter_end = function () return '\\par' end
  --
  return layout_qq(texts, typesetter_body, typesetter_end, opts)
end

-- Questions, subquestions ----------------------------------------------------

-- Helper function for Q that renders in Latex the source of a question and
-- a 'note'. Either or both arguments may be nil.
local q_sourcenote = function(source, note)
  local bits = pl.List()
  if source then
    local x = F([[\enspace {\color{Mulberry}\small [%s]}]], source)
    bits:append(x)
  end
  if note then
    local x = F([[\enspace {\color{CadetBlue}\small\itshape (%s)} ]], note)
    bits:append(x)
  end
  return bits:concat()
end

a.Q = 1
o:append 'Q.vspace = 6pt, Q.color = blue, Q.newpage = false'
f.Q = function(n, args, o, kw)
  lbt.api.counter_reset('qq')
  lbt.api.counter_reset('mc')
  local q = lbt.api.counter_inc('q')
  local template = pl.List()
  if o.newpage then
    template:append [[\clearpage]]
  end
  template:append [[
    \vspace{!VSPACE!}
    {\color{!COLOR!}\bfseries Question~!NUMBER!}{!SOURCENOTE!}\quad !TEXT! \par
  ]]
  template.values = {
    VSPACE = o.vspace, COLOR = o.color, NUMBER = q,
    SOURCENOTE = q_sourcenote(kw.source, kw.note),
    TEXT = args[1] }
  return T(template)
  -- template = template:concat('\n')
  -- return F(template, vsp, col, q, args[1])
end

a.QQ = 1
o:append 'QQ.vspace = 0pt'
f.QQ = function(n, args, o)
  local qq = lbt.api.counter_inc('qq')
  local vsp = o.vspace
  local label_style = [[\textcolor{blue}{(\alph*)}]]
  local template = [[
    \begin{enumerate}[align=left, topsep=3pt, start=%d, label=%s, left=1em .. 3.2em]
      \item %s
    \end{enumerate}
    \vspace{%s}
  ]]
  return F(template, qq, label_style, args[1], vsp)
end

a['QQ*'] = '2+'
f['QQ*'] = function(n, args, o)
  -- 1. Parse options to get ncols and vspace and hpack.
  local t = get_options_ncols_vspace_hpack('QQ*', args)
  local options
  if t[1] == 'error' then
    return { error = t[2] }
  elseif t[1] == 'ok' then
    options = t[2]
    args = t[3]
  else
    lbt.err.E001_internal_logic_error('QQ*')
  end
  local ncols  = options.ncols
  local vspace = options.vspace or '0pt'
  local hpack  = options.hpack or 'column'
  -- 2. Decide whether we are doing columns or hfill.
  if hpack == 'column' then
    local settings = { leftindent = '1em', alphabet = 'latin', labelcolor = 'blue',
                       labelwidth = '2em',
                       ncols = ncols, vspace = vspace, counter = 'qq' }
    return layout_qq_columns(args, settings)
  elseif hpack == 'hfill' then
    local settings = { leftindent = '1em', alphabet = 'latin', labelcolor = 'blue',
                       labelwidth = '2em',
                       counter = 'qq' }
    return layout_qq_hfill(args, settings)
  else
    return { error = F([[Invalid value for QQ* option \Verb|hpack| -- use \Verb|column| or |hfill|]]) }
  end
end

-- Multiple choice options ----------------------------------------------------

-- MC lays out vertically as many options as are given using A, B, C, ...
a.MC = '1+'
o:append 'MC.format = (A)'
f.MC = function(n, args, o)
  -- We employ an enumerate environment with one line1, many line2 and one line3.
  local line0 = [[ \begin{adjustwidth}{2em}{}]]
  local line1 = [[ \begin{enumerate}[%s, align=left, topsep=3pt, left=1em .. 3.5em] ]]
  local line2 = [[   \item %s ]]
  local line3 = [[ \end{enumerate} ]]
  local line4 = [[ \end{adjustwidth} ]]
  local result = pl.List()
  result:append(line0)
  result:append(F(line1, o('MC.format')))
  for x in args:iter() do
    result:append(F(line2, x))
  end
  result:append(line3)
  result:append(line4)
  return result:join('\n')
end

-- MC* lays out horizontally just like QQ*, with the same options:
--   hpack = [columns|hfill], ncols, vspace
a['MC*'] = '1+'
-- s['MC*'] = {}        -- think about format = (A)
f['MC*'] = function (n, args, o)
  -- 1. Parse options to get ncols and vspace and hpack.
  local t = get_options_ncols_vspace_hpack('MC*', args)
  local options
  if t[1] == 'error' then
    return { error = t[2] }
  elseif t[1] == 'ok' then
    options = t[2]
    args = t[3]
  else
    lbt.err.E001_internal_logic_error('MC*')
  end
  local ncols  = options.ncols
  local vspace = options.vspace or '0pt'
  local hpack  = options.hpack or 'column'
  -- 2. Decide whether we are doing columns or hfill.
  if hpack == 'column' then
    local settings = { leftindent = '3em', alphabet = 'Latin', labelcolor = nil,
                       labelwidth = '2.5em',
                       ncols = ncols, vspace = vspace, counter = 'mc' }
    return layout_qq_columns(args, settings)
  elseif hpack == 'hfill' then
    local settings = { leftindent = '3em', alphabet = 'Latin', labelcolor = nil,
                       labelwidth = '2.5em',
                       counter = 'mc' }
    return layout_qq_hfill(args, settings)
  else
    return { error = F([[Invalid value for MC* option \Verb|hpack| -- use \Verb|column| or |hfill|]]) }
  end
end


-- Hints and answers ----------------------------------------------------------


a.HINT = 1
f.HINT = function(n, args, o)
  local q = lbt.api.counter_value("q")
  local hints = lbt.api.data_get("hints", pl.OrderedMap())
  hints[q] = args[1]
  return "{}"
end

a.ANSWER = 1
f.ANSWER = function(n, args, o)
  local q = lbt.api.counter_value("q")
  local answers = lbt.api.data_get("answers", pl.OrderedMap())
  answers[q] = args[1]
  return "{}"
end

a.SHOWHINTS = 0
f.SHOWHINTS = function(n, args, o)
  local text = pl.List()
  local hints = lbt.api.data_get("hints", pl.OrderedMap())
  text:append([[\begin{small}]])
  for q, h in hints:iter() do
    local x = F([[\par\textcolor{Mulberry}{\textbf{%d}} \enspace \textcolor{darkgray}{%s}]], q, h)
    text:append(x)
  end
  text:append([[\end{small} \par]])
  return text:concat('\n')
end

a.SHOWANSWERS = 0
f.SHOWANSWERS = function(n, args, o)
  local text = pl.List()
  local answers = lbt.api.data_get("answers", pl.OrderedMap())
  text:append([[\begin{small}]])
  for q, a in answers:iter() do
    local x = F([[\par\textcolor{Mulberry}{\textbf{%d}} \enspace \textcolor{darkgray}{%s}]], q, a)
    text:append(x)
  end
  text:append([[\end{small} \par]])
  return text:concat('\n')
end

a.HINTRESET = 0
f.HINTRESET = function(n, args, o)
  lbt.api.data_set("hints", pl.OrderedMap())
  return '{}'
end

a.ANSWERRESET = 0
f.ANSWERRESET = function(n, args, o)
  lbt.api.data_set("answers", pl.OrderedMap())
  return '{}'
end

a.QRESET = 0
f.QRESET = function(n, args, sr)
  lbt.api.counter_reset('q')
  return '{}'
end


-------------------------------------------------------------------------------


return {
  name      = 'lbt.Questions',
  desc      = 'Questions, hints, answers for worksheet, exam, course notes',
  sources   = {},
  init      = nil,
  expand    = nil,
  functions = f,
  arguments = a,
  -- styles    = s,
  default_options = o
}

