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
  -- 1. Parse options to get ncols and vspace.
  local options, args = lbt.util.extract_option_argument(args)
  local errormsg = [[First argument to QQ* must specify the number of columns (e.g. \verb|[ncols=3, vspace=20pt]|)]]
  if options == nil then
    return { error = errormsg }
  end
  options = lbt.util.parse_options(options)
  if options == nil or options.ncols == nil then
    return { error = errormsg }
  end
  local ncols = options.ncols
  local vspace = options.vspace or '0pt'
  -- 2. Set up result list and function to add to it.
  local label_style = [[\textcolor{blue}{(\alph*)}]]
  local result = pl.List()
  local add = function(line, ...)
    result:append(F(line, ...))
  end
  -- 3. Table header.
  add([[\begin{tblr}{colspec = {%s},]], string.rep('X[1,l]', options.ncols))
  add([[  measure=vbox, stretch=-1]])
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
  end
  -- 5. Table footer.
  add([[\end{tblr}]])
  -- 6. Return value.
  return result:concat('\n')
end

-- MC lays out vertically as many options as are given using A, B, C, ...
a.MC = '1+'
s.MC = { format = '(A)' }
f.MC = function(n, args, sr)
  -- We emply an enumerate environment with one line1, many line2 and one line3.
  local line1 = [[ \begin{enumerate}[%s, topsep=3pt, left=13mm .. 23mm] ]]
  local line2 = [[   \item %s ]]
  local line3 = [[ \end{enumerate} ]]
  local result = pl.List()
  result:append(F(line1, sr('MC.format')))
  for x in args:iter() do
    result:append(F(line2, x))
  end
  result:append(line3)
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

