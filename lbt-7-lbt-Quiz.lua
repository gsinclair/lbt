-- +-----------------------------------------------------+
-- | Template: lbt.Quiz                                  |
-- |                                                     |
-- | Like worksheet (WS0) but with more detail in header |
-- | (name, mark, etc.)                                  |
-- +-----------------------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand

local f = {}
local a = {}
local s = {}
local m = {}


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

  return T {
    [[\newpage]],
    [[\setlength{\parindent}{0em}]],
    [[\newcommand{\MarkBox}{\boxed{\phantom{\frac{xwx}{2}}}}]],
    '',
    header_and_rule(prefix, quiz_number, title, course, topic),
    '',
    [[\vspace{24pt}]],
    '',
    lbt.util.latex_expand_content_list('BODY', pc, tr, sr),
    '',
    [[\clearpage]],
  }
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
