-- +---------------------------------------------------------------------+
-- | Template: lbt.WS1                                                   |
-- |                                                                     |
-- | Purpose: Educational worksheet similar to WS0 but with additional   |
-- |          structure: heading number, intro box, outro challenge.     |
-- |          The heading number means it is explicitly meant to be      |
-- |          part of a series of worksheets.                            |
-- |                                                                     |
-- | It builds on the idea of WS0 and uses it as a source, so all WS0    |
-- | commands are available. Regarding the overall template expansion,   |
-- | though, WS1 is similar to WS0 but can't really share its source     |
-- | code. So we just have to take a copy-and-paste approach. That's not |
-- | ideal, but considering the benefits we get from making a template,  |
-- | the trade-off is OK.                                                |
-- |                                                                     |
-- | Another approach would be to implement the WS1-specific features as |
-- | commands that could be used in a WS0 worksheet via SOURCE (soon to  |
-- | be renamed INCLUDE). Three reasons I am not taking this approach:   |
-- |  * WS0 does not have a way to include a counter in the title, and   |
-- |    I don't want to fudge an implementation for that;                |
-- |  * It is good to have an official example of one template partially |
-- |    building upon another.                                           |
-- |  * It demonstrates a template that has more author-content sections |
-- |    than just @META and +BODY.                                       |
-- +---------------------------------------------------------------------+

-- Note to readers: this is an explicit template with an expand function but no
-- additional functionality of its own. Any extra features I need while creating
-- worksheets using this template will be put in WS0 (unless that would be a bad
-- choice for some reason) so that they are more generally usable.

local F = string.format

local f = {}
local a = {}
local op = {}
local m = {}

op.WS1 = { title_color = 'MidnightBlue', teacher_notes_color = 'blue' }

-- Set styles to headings in WS0.   (Consering this...)
-- s.WS0 = { heading_color = 'MidnightBlue' }

local function init()
end

local function intro_box(data)
  local x = pl.List()
  local helper = function(token, heading)
    if data[token] then
      local text = data[token]
      local l, r = nil    -- latex code for left and right column
      if token == 'WHY' or token == 'NOTE' then
        l = F([[\itshape\color{CadetBlue} %s]], heading)
        r = F([[\itshape\color{CadetBlue} %s]], text)
      else
        l = F([[\color{Plum} %s]], heading)
        r = F([[\color{Plum} %s]], text)
      end
      x:append(F([[  {%s} & {%s} \\ ]], l, r))
    end
  end
  x:append([[\begingroup]])
  x:append([[\begin{center}]])
  x:append([[\begin{tblr}{
    width=0.8\textwidth,
    colspec = lX,
    rowsep = 0.4em,
    column{1} = {font = \bfseries}
  }]])
  helper('PROBLEM', 'Problem')
  helper('WHY', 'Why?')
  helper('SOLUTION', 'Solution')
  helper('NOTE', 'Note')
  x:append([[\end{tblr}]])
  x:append([[\end{center}]])
  x:append([[\endgroup]])
  return x:join('\n')
end


-- Input: (pc) parsed content   (ocr) opcode resolver   (ol) option lookup
local function expand(pc)
  local n        = lbt.api.persistent_counter_inc('WS1-worksheet')
  local title    = lbt.util.content_meta_or_error(pc, 'TITLE')
  local course   = lbt.util.content_meta_or_error(pc, 'COURSE')
  local tnotes   = lbt.util.content_meta_or_nil(pc, 'TEACHERNOTES') or '(none specified)'
  local titlecol = lbt.util.resolve_oparg('WS1.title_color')
  local tncol    = lbt.util.resolve_oparg('WS1.teacher_notes_color')

  -- 1. Preamble
  local a = [[
    \setlength{\parindent}{0em}
    \setlength{\parskip}{6pt plus 2pt minus 2pt}
    \newcommand{\LeftMargin}[1]{\makebox[0pt][r]{#1}}
    \newcommand{\TitleSet}[3]{%%
      \LeftMargin{{\itshape\color{Gray}\##2\enspace}}%%
      {\bfseries\color{#1}#3}%%
    }
    \newcommand{\CourseSet}[1]{{\color{Gray}\itshape #1}}
  ]]

  -- 2. Teacher notes
  local b = F([[
    \newpage
    \begingroup
    \color{%s}
    \fbox{Teacher's notes on \textbf{%d. %s}}
    \vspace{2.5em}

    %s

    \endgroup
  ]], tncol, n, title, tnotes)

  -- 3. New page and table-of-contents addition
  local c = F([[
    \newpage
    \addcontentsline{toc}{\lbtCurrentContentsLevel}{Worksheet %d: %s}
  ]], n, title)

  -- 4. Worksheet title and horizontal rule
  local d = F([[
    \TitleSet{%s}{%d}{%s} \hfill \CourseSet{%s}
    \rule[8pt]{\textwidth}{0.4pt}
  ]], titlecol, n, title, course)

  -- 5. Intro box (problem, solution, why, note)
  local data = lbt.util.content_dictionary_or_nil(pc, 'INTRO')
  local e = data and intro_box(data) or ''

  -- 6. General body
  local f = F([[
    \bigskip

    %s
  ]], lbt.util.latex_expand_content_list('BODY', pc))

  -- 7. Outro
  local g = F([[
    \vfill

    %s

    \clearpage
  ]], lbt.util.latex_expand_content_list('OUTRO', pc))

  -- Put it all together!
  return lbt.util.combine_latex_fragments(a,b,c,d,e,f,g)
end


return {
  name      = 'lbt.WS1',
  desc      = 'A worksheet like WS0 but with added structure (as an example)',
  sources   = { 'lbt.WS0', 'lbt.Questions' },
  init      = nil,
  expand    = expand,
  functions = f,
  opargs = op,
  posargs = a,
  macros    = m,
}
