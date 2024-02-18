-- +----------------------------------------+
-- | Template: lbt.Questions                |
-- |                                        |
-- | Purpose: Questions, hints, answers for |
-- |          worksheets, exams, ...        |
-- +----------------------------------------+

local F = string.format

local f = {}
local a = {}
local s = {}

f.Q = function(n, args)
  return F([[\textbf{Question }%d\enspace %s]], lbt.api.counter_inc('q'), args[1])
end

a.Q = 1
s.Q = { vspace = '6pt', color = 'blue' }
f.Q = function(n, args, s)
  lbt.api.counter_reset('qq')
  lbt.api.counter_reset('mc')
  local vsp, col = s('Q.vspace Q.color')
  local q = lbt.api.counter_inc('q')
  local template = [[
    \vspace{%s}
    {\color{%s}\bfseries Question~%d}\quad %s \par
  ]]
  return F(template, vsp, col, q, args[1])
end

a.QQ = 1
f.QQ = function(n, args, s)
  local qq = lbt.api.counter_inc('qq')
  local label_style = [[\textcolor{blue}{(\alph*)}]]
  local template = [[
    \begin{enumerate}[align=left, topsep=3pt, start=%d, label=%s, left=1em .. 3.2em]
      \item %s
    \end{enumerate}
  ]]
  return F(template, qq, label_style, args[1])
end

a['QQ*'] = '2+'
f['QQ*'] = function(n, args, s)
  -- 1. Parse options to get ncols and vspace and hpack.
  local options, args = lbt.util.extract_option_argument(args)
  local errormsg = [[First argument to QQ* must specify the number of columns (e.g. \Verb|[ncols=3, vspace=20pt]|)]]
  if options == nil then
    return { error = errormsg }
  end
  options = lbt.util.parse_options(options)
  if options == nil or options.ncols == nil then
    return { error = errormsg }
  end
  local ncols  = options.ncols
  local vspace = options.vspace or '0pt'
  local hpack  = options.hpack or 'column'
  -- 2. Set up result list and function to add to it.
  local result = pl.List()
  local add = function(line, ...)
    result:append(F(line, ...))
  end
  --
  -- We now decide whether to lay this out in equal-width columns using a table
  -- or with even spacing using \hfill (only suitable if there is just one line).
  --
  if hpack == 'column' then
    local label_style = [[\textcolor{blue}{(\alph*)}]]
    -- 3. Table header.
    add([[\begin{tblr}{colspec = {%s},]], string.rep('X[1,l]', options.ncols))
    add([[  colsep={0pt}, measure=vbox, stretch=-1]])
    add([[}]])
    -- 4. Table body.
    local question_template = [[
      \begin{enumerate}[align=left, topsep=0pt, start=%d, label=%s, left=1em .. 3.2em]
        \item %s
      \end{enumerate} ]]
    for i = 1,#args do
      local qtext = args[i]
      add(question_template, i, label_style, qtext)
      if i % ncols == 0 or i == #args then
        add([[\\[%s] ]], vspace)
      else
        add([[ & ]])
      end
      lbt.api.counter_inc('qq')    -- in case we want to put a normal QQ after this
    end
    -- 5. Table footer.
    add([[\end{tblr} \par]])
    -- 6. Return value.
    return result:concat('\n')
  elseif hpack == 'hfill' then
    -- We are using \hfill to lay out the bits, but we need to match the initial spacing
    -- of the layout strategy above. It was not easy to get this code right, but at least
    -- it is short. Main difficulty is avoiding unwanted spaces; hence 'template' is
    -- tightly packed.
    for i = 1,#args do
      local qtext = args[i]
      add([[\hspace{1em}]])
      local qq = lbt.api.counter_inc('qq')
      local marker = lbt.util.number_in_alphabet(qq, 'latin')
      local template = [[\parbox{2.2em}{\color{blue}(%s)}%s\hfill{}]]
      add(template, marker, qtext)
    end
    add([[\par]])
    return result:concat('')
  else
    return { error = F([[Invalid value for QQ* option \Verb|hpack| -- use \Verb|column| or |hfill|]]) }
  end
end

-- MC lays out vertically as many options as are given using A, B, C, ...
a.MC = '1+'
s.MC = { format = '(A)' }
f.MC = function(n, args, sr)
  -- We emply an enumerate environment with one line1, many line2 and one line3.
  local line0 = [[ \begin{adjustwidth}{1em}{}]]
  local line1 = [[ \begin{enumerate}[%s, align=left, topsep=3pt, left=1em .. 3.5em] ]]
  local line2 = [[   \item %s ]]
  local line3 = [[ \end{enumerate} ]]
  local line4 = [[ \end{adjustwidth} ]]
  local result = pl.List()
  result:append(line0)
  result:append(F(line1, sr('MC.format')))
  for x in args:iter() do
    result:append(F(line2, x))
  end
  result:append(line3)
  result:append(line4)
  return result:join('\n')
end



return {
  name      = 'lbt.Questions',
  desc      = 'Questions, hints, answers for worksheet, exam, course notes',
  sources   = {},
  init      = nil,
  expand    = nil,
  functions = f,
  arguments = a,
  styles    = s
}

