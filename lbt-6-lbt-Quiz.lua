-- +-----------------------------------------------------+
-- | Template: lbt.Quiz                                  |
-- |                                                     |
-- | Like worksheet (WS0) but with more detail in header |
-- | (name, mark, etc.)                                  |
-- +-----------------------------------------------------+

local F = string.format

local f = {}
local a = {}
local s = {}
local m = {}


local function template_text()
  return [[
    \newpage
    \setlength{\parindent}{0em}
    \newcommand{\MarkBox}{\boxed{\phantom{\frac{xwx}{2}}}}

    HEADER AND RULE

    \vspace{24pt}

    BODY

    \clearpage
  ]]
end

-- TODO generalise this and put it in the content lua file for all to access.
-- Have a flag that allows nil value versus an error message.
local function meta_value_or_err(x)
  local val = GSC.content.META[x]
  if val then
    return val
  else
    return GSC.util.tex_error(F([[No value for '%s']], x))
  end
end

local function header_and_rule(prefix, n, title, course, topic)
  if n == nil then
    lbt.util.template_error_quit('Quiz number is nil')
  end
  local fulltitle = nil
  if prefix and title then
    fulltitle = F([[Quiz %s.%d (%s)]], prefix, n, title)
  elseif prefix then
    fulltitle = F([[Quiz %s.%d]], prefix, n)
  elseif title then
    fulltitle = F([[Quiz \#%d (%s)]], n, title)
  else
    fulltitle = F([[Quiz \#%d]], n)
  end
  local a = F([[\addcontentsline{toc}{section}{\textbf{%s}}]], fulltitle)
  local b = F([[\textbf{%s} \hfill Name \rule[-3pt]{4cm}{0.5pt} \hfill Mark \MarkBox \quad Presentation \MarkBox \\[6pt] ]], fulltitle)
  local c = F([[{\small \color{CadetBlue} \emph{Course}\quad %s \hfill \emph{Topic}\quad %s \hfill \emph{Number}\quad %d \\ }]], course, topic, n)
  local d = F([[\rule{\textwidth}{1pt} \par]])
  return table.concat({a,b,c,d}, '\n')
end

local function init()
end

local function expand(pc, tr, sr)
  local prefix      = lbt.util.content_meta_or_nil(pc, 'PREFIX')
  local quiz_number = lbt.api.persistent_counter_inc('quiz')
  local title       = lbt.util.content_meta_or_nil(pc, 'TITLE')
  local course      = lbt.util.content_meta_or_error(pc, 'COURSE')
  local topic       = lbt.util.content_meta_or_error(pc, 'TOPIC')
  local x = template_text()
  x = x:gsub("HEADER AND RULE", header_and_rule(prefix, quiz_number, title, course, topic))
  local body_latex = lbt.util.latex_expand_content_list('BODY', pc, tr, sr)
  x = x:gsub('BODY', body_latex)
  return x
end

return {
  name      = 'lbt.Quiz',
  desc      = 'Quiz for educational settings',
  sources   = {"lbt.WS0", "lbt.Questions"},
  init      = init,
  expand    = expand,
  functions = f,
  styles    = s,
  arguments = a,
  macros    = m,
}
