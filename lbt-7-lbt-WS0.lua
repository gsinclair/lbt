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
local op = {}
local a = {}
local m = {}

op.WS0 = { title_color = 'BlueViolet', teacher_notes_color = 'blue' }

local function init()
end

-- Input: (pc) parsed content
local function expand(pc)
  local title    = lbt.util.content_meta_or_error(pc, 'TITLE')
  local course   = lbt.util.content_meta_or_error(pc, 'COURSE')
  local tnotes   = lbt.util.content_meta_or_nil(pc, 'TEACHERNOTES') or '(none specified)'
  local titlecol = lbt.util.resolve_oparg('WS0.title_color')
  local tncol    = lbt.util.resolve_oparg('WS0.teacher_notes_color')

  -- 1. Preamble
  local a = [[
    \setlength{\parindent}{0em}
    \setlength{\parskip}{6pt plus 2pt minus 2pt}
    \newcommand{\TitleSet}[2]{{\bfseries\color{#1}#2}}
    \newcommand{\CourseSet}[1]{{\color{CadetBlue}\itshape #1}}
    \tcbset{colback=blue!10!white}
  ]]

  -- 2. Teacher notes
  local b = F([[
    \newpage
    \begingroup
    \color{%s}
    \fbox{Teacher's notes on \textbf{%s}}
    \vspace{2.5em}

    %s

    \endgroup
  ]], tncol, title, tnotes)

  -- 3. New page and table-of-contents addition
  local c = F([[
    \newpage
    \addcontentsline{toc}{\lbtCurrentContentsLevel}{Worksheet: %s}
  ]], title)

  -- 4. Worksheet title and horizontal rule
  local d = nil
  if course == nil then
    d = F([[
      \TitleSet{%s}{%s}
      \rule[8pt]{\textwidth}{0.4pt}
    ]], titlecol, title, course)
  else
    d = F([[
      \TitleSet{%s}{%s} \hfill \CourseSet{%s}
      \rule[8pt]{\textwidth}{0.4pt}
    ]], titlecol, title, course)
  end

  -- 5. General body
  local e = F([[
    \bigskip

    %s

    \clearpage
  ]], lbt.util.latex_expand_content_list('BODY', pc))

  -- Put it all together!
  return lbt.util.combine_latex_fragments(a,b,c,d,e)
end

-- EXAMPLE and NOTE and CHALLENGE and general headings ------------------------

local function heading_and_text_indent(heading, color, text)
  local colorsetting = ''
  if color then colorsetting = F([[\color{%s}]], color) end
  return F([[
{%s \bfseries %s} \par
\begin{adjustwidth}{2em}{}
  %s
\end{adjustwidth} \par
  ]], colorsetting, heading, text)
end

local function heading_and_text_inline(heading, color, text)
  local colorsetting = ''
  if color then colorsetting = F([[\color{%s}]], color) end
  return F([[ {%s \bfseries %s} \quad %s \par ]], colorsetting, heading, text)
end

op.EXAMPLE = { color = blue }
a.EXAMPLE = 1
f.EXAMPLE = function (n, args, o)
  return heading_and_text_indent('Example', o('EXAMPLE.color'), args[1])
end

a['EXAMPLE*'] = 1
f['EXAMPLE*'] = function (n, args, o)
  return heading_and_text_inline('Example', o('EXAMPLE.color'), args[1])
end

op.NOTE = { color = 'Mahogany' }
a.NOTE = 1
f.NOTE = function (n, args, o)
  return heading_and_text_indent('Note', o('NOTE.color'), args[1])
end

a['NOTE*'] = 1
f['NOTE*'] = function (n, args, o)
  return heading_and_text_inline('Note', o('NOTE.color'), args[1])
end

op.CHALLENGE = { color = 'Plum' }
a.CHALLENGE = 1
f.CHALLENGE = function (n, args, o)
  lbt.api.counter_reset('qq')
  return heading_and_text_indent('Challenge', o('CHALLENGE.color'), args[1])
end

a['CHALLENGE*'] = 1
f['CHALLENGE*'] = function (n, args, o)
  lbt.api.counter_reset('qq')
  return heading_and_text_inline('Challenge', o('CHALLENGE.color'), args[1])
end

a.HEADING = '2-3'
f.HEADING = function(n, args)
  if n == 2 then
    return heading_and_text_indent(args[1], nil, args[2])
  elseif n == 3 then
    return heading_and_text_indent(args[1], args[2], args[3])
  end
end

a['HEADING*'] = '2-3'
f['HEADING*'] = function(n, args)
  if n == 2 then
    return heading_and_text_inline(args[1], nil, args[2])
  elseif n == 3 then
    return heading_and_text_inline(args[1], args[2], args[3])
  end
end

-- smallnote macro ------------------------------------------------------------

m.smallnote = function(text)
  return F([[\textcolor{CadetBlue}{\small %s} ]], text)
end


return {
  name      = 'lbt.WS0',
  desc      = 'A worksheet with title, course, teacher notes',
  sources   = {"lbt.Questions"},
  init      = init,
  expand    = expand,
  functions = f,
  opargs = op,
  posargs = a,
  macros    = m,
}

