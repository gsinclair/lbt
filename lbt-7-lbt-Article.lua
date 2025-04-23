
-- +----------------------------------------+
-- | Template: lbt.Article                  |
-- |                                        |
-- | Purpose: An article with title, author |
-- |          abstract, headings.           |
-- +----------------------------------------+

local F = string.format
local f = {}
local a = {}
local op = {}
local m = {}

op.Article = { parskip = '2pt plus 2pt minus 1pt', parindent = '15pt'}

-- Input: (pc) parsed content   (ocr) opcode resolver   (ol) option lookup
local function expand(pc)
  local title    = lbt.util.content_meta_or_error(pc, 'TITLE')
  local author   = lbt.util.content_meta_or_error(pc, 'AUTHOR')
  local date     = lbt.util.content_meta_or_nil(pc, 'DATE')
  local tsize    = lbt.util.content_meta_or_nil(pc, 'TITLE_SIZE') or 'Large'
  local getopt   = lbt.util.resolve_oparg

  -- 1. Preamble
  local a = F([[
    \setlength{\parindent}{%s}
    \setlength{\parskip}{%s}
  ]], getopt('Article.parindent'), getopt('Article.parskip'))

  -- 2. New page and table-of-contents addition
  local b = F([[
    \newpage
    \addcontentsline{toc}{\lbtCurrentContentsLevel}{Article: %s}
  ]], title)

  -- 3. Title, author, date
  local authordate = nil
  if date then
    authordate = F([[%s \\[0.5em] %s]], author, date)
  else
    authordate = author
  end
  local c = F([[
    \begin{%s}
    \noindent %s
    \end{%s} \\[1em]
    %s
  ]], tsize, title, tsize, authordate)

  -- 4. General body
  local d = F([[
    \bigskip

    %s
  ]], lbt.util.latex_expand_content_list('BODY', pc))

  -- Put it all together!
  return lbt.util.combine_latex_fragments(a,b,c,d)
end


a.ABSTRACT = '1+'
f.ABSTRACT = function(n, args, o)
  -- Each argument is a paragraph. We set the abstract with thinner margins and
  -- an inline heading, and in smaller text.
  local a = [[\begin{adjustwidth}{4em}{4em}]]
  local b = [[\setlength{\parindent}{0pt} \setlength{\parskip}{0.5ex}]]
  local c = [[\begin{small}]]
  local d = F([[\textbf{Abstract.}\enspace %s]], args[1])
  local e = pl.List()
  if n > 1 then
    for i=2,n do
      e:append([[\par]])
      e:append(args[i])
    end
  end
  e = e:concat('\n')
  local f = [[\end{small}]]
  local g = [[\end{adjustwidth}]]
  return lbt.util.combine_latex_fragments(a,b,c,d,e,f,g)
end

a.HEADING = '1'
-- Experiment, Oct 2024. Use \section* to implement HEADING. We don't want to
-- affect the table of contents, and we didn't want section numbers anyway.
f.HEADING = function(n, args, o)
  return F([[\section*{%s}]], args[1])
end


return {
  name      = 'lbt.Article',
  sources   = {},
  desc      = 'An article with title, author, date, abstract, headings',
  init      = nil,
  expand    = expand,
  functions = f,
  opargs = op,
  posargs = a,
  macros    = m,
}

