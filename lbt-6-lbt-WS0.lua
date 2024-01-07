-- +---------------------------------------+
-- | Template: lbt.WS0                     |
-- |                                       |
-- | Purpose: Simple worksheet with title, |
-- |          course and teacher notes.    |
-- +---------------------------------------+

-- This code will be rendered over two pages: one for the teacher's notes and
-- one for the worksheet. The title will be used on both pages. A table of
-- contents entry will be generated for the worksheet but not the teacher's
-- notes. The course, if given, will appear as a subtle part of the title. The
-- title and course will appear at the top of the page and be underlined with a
-- full-width rule. A little space will appear before the body, and the rest is
-- up to you!
--
-- The teacher's notes appear entirely in blue so that they are easily visually
-- distinguished from the worksheet when flicking through the pages.


local F = string.format
local f = {}
local s = {}
local a = {}

s.WS0 = { title_color = 'CadetBlue', teacher_notes_color = 'blue' }

local function template_text(tn_color)
  lbt.log('dev', 'WS0 template_text <%s>', tn_color)
  return F([[
\newpage

TEACHERNOTES

\newpage

\addcontentsline{toc}{section}{TITLESINGLE}

TITLELINE
\rule{\textwidth}{0.4pt}

\vspace{24pt}

BODY

\clearpage
  ]], tn_color, tn_color)
end

local function teacher_notes(text, color)
  return F([[
\begingroup
\setlength{\parindent}{0em}
\setlength{\parskip}{6pt plus 2pt minus 2pt}
\fbox{\color{CadetBlue} Teacher's notes on \textbf{Network hardware, IDE, digital currency}}
\vspace{18pt}

\color{CadetBlue}
This is the first piece of work for 2023. Network hardware is sort of revision. IDE is new. Digital currency: we watched a video right at the end of 2022 but didn't write notes. \par \lipsum[1] \par \lipsum[3]
\endgroup
  ]])
end

local function title_line(title, course, color)
  lbt.log('dev', 'WS0 title_line <%s> <%s <%s>', title, course, color)
  if course then
    return F([[\textbf{%s} \hfill {\color{%s}\itshape %s}]], title, color, course)
  else
    return F([[\textbf{%s}]], title)
  end
end

local function init()
  -- lbt.api.counter_reset('q')   -- Needed? I think not.
end

-- Input: (pc) parsed content   (tr) token resolver   (sr) style resolver
local function expand(pc, tr, sr)
  local title  = lbt.util.content_meta(pc, 'TITLE') or '(no title)'
  local course = lbt.util.content_meta(pc, 'COURSE') or nil
  local tnotes  = lbt.util.content_meta(pc, 'TEACHERNOTES') or "(none specified)"
  local tcol   = sr('WS0.title_color')
  local tncol  = sr('WS0.teacher_notes_color')
  local result = template_text(tcol)

  -- DEBUGGER()

  -- Substitute KEY WORDS in the template text for their actual values.
  result = result:gsub('TEACHERNOTES', teacher_notes(tnotes, tncol))
  result = result:gsub('TITLESINGLE', title)
  result = result:gsub('TITLELINE', title_line(title, course, tcol))

  -- Evaluate the BODY and substitute it in.
  -- Most structural templates will need code very much like this.
  local body_latex = lbt.util.latex_expand_content_list('BODY', pc, tr, sr)
  result = result:gsub('BODY', body_latex)

  return result
end

return {
  name      = 'lbt.WS0',
  desc      = 'A worksheet with title, course, teacher notes',
  sources   = {"lbt.Questions"},
  init      = init,
  expand    = expand,
  functions = f,
  styles    = s,
  arguments = a
}

