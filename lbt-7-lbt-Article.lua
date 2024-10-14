
-- +----------------------------------------+
-- | Template: lbt.Article                  |
-- |                                        |
-- | Purpose: An article with title, author |
-- |          abstract, headings.           |
-- +----------------------------------------+

local F = string.format
local f = {}
local a = {}
local o = pl.List()
local m = {}

-- s.Article = { parstyle = 'skip',
--               parskip = '6pt plus 2pt minus 2pt',
--               parindent = '1em' }
-- o:append 'Article.parstyle = skip, Article.parskip = 6pt plus 2pt minus 2pt, Article.parindent = 1em'
o:append 'Article.parskip = 2pt plus 2pt minus 1pt, Article.parindent = 15pt'

local function init()
end

-- Input: (pc) parsed content   (ocr) opcode resolver   (ol) option lookup
local function expand(pc, ocr, ol)
  local title    = lbt.util.content_meta_or_error(pc, 'TITLE')
  local author   = lbt.util.content_meta_or_error(pc, 'AUTHOR')
  local date     = lbt.util.content_meta_or_nil(pc, 'DATE')
  local tsize    = lbt.util.content_meta_or_nil(pc, 'TITLE_SIZE') or 'Large'

  -- 1. Preamble
  local a = F([[
    \setlength{\parindent}{%s}
    \setlength{\parskip}{%s}
  ]], ol('Article.parindent'), ol('Article.parskip'))

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
  ]], lbt.util.latex_expand_content_list('BODY', pc, ocr, ol))

  -- Put it all together!
  return lbt.util.combine_latex_fragments(a,b,c,d)
end


a.ABSTRACT = '1+'
f.ABSTRACT = function(n, args, o)
  -- Each argument is a paragraph. We set the abstract with thinner margins and
  -- an inline heading, and in smaller text.
  local a = [[\begin{adjustwidth}{4em}{4em}]]
  local b = [[\begin{small}]]
  local c = F([[\textbf{Abstract.}\enspace %s]], args[1])
  local d = pl.List()
  if n > 1 then
    for i=2,n do
      d:append([[\par]])
      d:append(args[i])
    end
  end
  d = d:concat('\n')
  local e = [[\end{small}]]
  local f = [[\end{adjustwidth}]]
  return lbt.util.combine_latex_fragments(a,b,c,d,e,f)
end

a.HEADING = '1'
f.HEADING = function(n, args, o)
  local prespace = '1em'
  local postspace = nil
  if o('Article.parstyle') == 'indent' then
    postspace = '1em'
  else
    postspace = '0pt'
  end
  return F([[
    \vspace{%s}
    \textbf{%s}
    \vspace{%s}
    \par
  ]], prespace, args[1], postspace)
end


return {
  name      = 'lbt.Article',
  sources   = {},
  desc      = 'An article with title, author, date, abstract, headings',
  init      = init,
  expand    = expand,
  functions = f,
  default_options = o,
  arguments = a,
  macros    = m,
}

