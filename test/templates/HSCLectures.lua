-- lbt project: test template
--
--
-- HSC-Lectures is a template developed in June 2023 for the purposes of
-- MANSW HSC Lectures in Extension 2. Requirements:
--  * A title page
--  * Headings
--  * New page with continued heading
--  * Questions and hints
--  * Page numbers would be nice
--
-- I should probably make modules to deal with headings and hints, but I am
-- pressed for time so I will just contain it here for now.
--
-- The code in this file started as a copy of WS0. Teachers notes are removed.


-- [[                                    ]]
-- [[     template text and              ]]
-- [[           supporting functions     ]]
-- [[                                    ]]

local function template_text()
  return [[
    \newpage

    \addcontentsline{toc}{section}{TITLESINGLE}

    TITLEPAGE

    \normalsize

    \newpage

    BODY

    \clearpage
  ]]
end

local function title_line(title, course)
  if course then
    return F([[\textbf{%s} \hfill {\color{CadetBlue}\itshape %s}]], title, course)
  else
    return F([[\textbf{%s}]], title)
  end
end

local function title_page(course, datestr, session, title, versionstring)
  return F([[
    \Large    \textcolor{CadetBlue}{MANSW HSC Lectures} \par
    \vspace{-2pt}
    \LARGE    \textcolor{NavyBlue}{%s} \par
    \Large    \textcolor{CadetBlue}{%s} \par

    \vfill

    \begin{center}
    \includegraphics[width=0.4\textwidth]{media/MANSW-logo.png}
    \end{center}

    \vfill
    \large    \textcolor{NavyBlue}{Session %s} \par
    \HUGE     \textcolor{NavyBlue}{%s} \par
    \bigskip
    \large    \textcolor{CadetBlue}{Presented by Gavin Sinclair}
    \footnotesize    \hfill\textcolor{gray}{\itshape Version %s}
  ]], course, datestr, session, title, versionstring)
end

local function body_latex(sources)
  local body = lbt.const.pc.BODY
  if body == nil then
    return ""
  else
    return GSC.fn.tex_eval_sequential(body, sources)
  end
end

-- [[                                    ]]
-- [[           template code            ]]
-- [[                                    ]]

local expand = function(pc, sources, styles)
  local c = pc.META.COURSE or "(no course specified)"
  local d = pc.META.DATE or "(no date specified)"
  local s = pc.META.SESSION or "(no session specified)"
  local t = pc.META.TITLE or "(no title specified)"
  local v = pc.META.VERSION or "(no version specified)"
  local x = template_text()

  -- The things that are most specific to this template.
  x = x:gsub("TITLESINGLE", t)
  x = x:gsub("TITLEPAGE", title_page(c, d, s, t, v))

  -- The things that are more general.
  x = x:gsub("BODY", body_latex(pc, sources, styles))

  return x
end

local f = {}

f.H1 = function(text)
  GSC.api.data_set("current-heading", text)
  return F([[
    \vspace{1em}
    \textbf{%s} \hfill \emoji{watermelon}
    \rule[6pt]{\textwidth}{0.4pt}
  ]], text)
end

f.NEWPAGE = function(text)
  if text == "heading" then
    heading = GSC.api.data_get("current-heading", "NO HEADING!")
    return F([[
      \clearpage

      \textcolor{Periwinkle}{{\small %s \textit{ continued\,\dots}}}
      \vspace{0.5em}
    ]], heading)
  elseif text == "noheading" then
    return F([[
      \clearpage
    ]])
  end
end

f.Q = function(text)
  local dp = { ["1"] = [[\bullet\circ\circ]], ["2"] = [[\bullet\bullet\circ]], ["3"] = [[\bullet\bullet\bullet]]}
  --    ^^ difficulty pictogram
  local question_module = require("lib.templates.Questions")
  local args = split(text, "::")
  if #args == 3 then
    local source, difficulty, question = table.unpack(args)
    text = F([[\source{%s\;\;%s} %s]], source, dp[difficulty], question)
    return question_module.Q(text)
  else
    return question_module.Q(text)
  end
end

f.HINT = function(text)
  local q = GSC.api.counter_value("q")
  local hints = GSC.api.data_get("hints", {})
  hints[q] = text
  return "{}"
end

f.ANSWER = function(text)
  local q = GSC.api.counter_value("q")
  local answers = GSC.api.data_get("answers", {})
  answers[q] = text
  return "{}"
end

f.SHOWHINTS = function(text)
  local text = {}
  local hints = GSC.api.data_get("hints", {})
  table.insert(text, [[\begin{small}]])
  for q, h in orderedPairs(hints) do
    table.insert(text, F([[\par\textcolor{Mulberry}{\textbf{%d}} \enspace \textcolor{darkgray}{%s}]], q, h))
  end
  table.insert(text, [[\end{small}]])
  return table.concat(text)
end

f.SHOWANSWERS = function(text)
  local text = {}
  local answers = GSC.api.data_get("answers", {})
  table.insert(text, [[\begin{small}]])
  for q, a in orderedPairs(answers) do
    table.insert(text, F([[\par\textcolor{Mulberry}{\textbf{%d}} \enspace \textcolor{darkgray}{%s}]], q, a))
  end
  table.insert(text, [[\end{small}]])
  return table.concat(text)
end

f.HINTRESET = function(text)
  GSC.api.data_set("hints", {})
  return '{}'
end

f.ANSWERRESET = function(text)
  GSC.api.data_set("answers", {})
  return '{}'
end

f.NOTE = function(text)
  return F([[
    \notebox{\small \textcolor{CadetBlue}{%s}}
  ]], text)
end

f.TIP = function(text)
  return F([[
    \tipbox{\small \textcolor{CadetBlue}{%s}}
  ]], text)
end

f.WARN = function(text)
  return F([[
    \warningbox{\small \textcolor{Plum}{%s}}
  ]], text)
end

f.FOLLOWUP = function(text)
  return F([[
    \tipbox{\small \textcolor{NavyBlue}{%s}}
  ]], text)
end


return {
  name = 'HSCLectures',
  desc = 'A test template for the lbt project',
  sources = {'lbt.Questions'},
  init = lbt.api.default_template_init,
  expand = lbt.api.default_template_expand,
  functions = f
}

