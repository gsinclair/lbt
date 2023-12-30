-- lbt project: test template
--
--
-- This template provides simple typesetting of questions, sub-questions and
-- multiple-choice options for worksheets, exams, etc.
--
-- It is a *test* template for the purposes of testing the lbt projects,
-- in particular styles.
--
-- Styles provided:
--  * Q.vspace            vertical space before a question
--  * Q.color             text color
--  * QQ.alphabet         (arabic), Arabic, roman, Roman
--  * MC.alphabet         arabic, (Arabic), roman, Roman
--
-- This is a content template, not a structure template. It uses the default
-- expansion routine. For initialisation, it creates/resets counter 'q'.

local F = string.format
local pp = pl.pretty.write


-- [[                                    ]]
-- [[           template code            ]]
-- [[                                    ]]

local expand = lbt.api.default_template_expand()

local f = {}
local a = {}
local s = {}

local init = function()
  lbt.api.counter_reset('q')
end

a.Q = 1
s.Q = { vspace = '12pt', color = 'blue' }
f.Q = function(n, args, s)
  lbt.api.counter_reset('qq')
  local vsp, col = s.get('Q.vspace Q.color')
  local q = lbt.api.counter_inc('q')
  return F([[{\vspace{%s}
              \bsferies\color{%s}Question~%d}\enspace %s]],
              vsp, col, q, args[1])
end

a.QQ = 1
s.QQ = { alphabet = 'latin' }
f.QQ = function(n, args, s)
  local alph = s.get('QQ.alphabet')
  local qq = lbt.api.counter_inc('qq')
  qq = lbt.util.number_in_alphabet(qq, alph)
  return F([[(%s)~%s]], qq, args[1])
end

a.MC = '1+'
f.MC = function(n, args, s)
  local result = pl.List()
  for i,x in ipairs(args) do
    local line = F([[(MC %s) \quad %s\\]],
      lbt.util.number_in_alphabet(i,'Latin'), x)
    result:append(line)
  end
  return result
end

return {
  name = 'TestQuestions',
  desc = 'A test template for the lbt project',
  sources = {},
  init = init,
  expand = lbt.api.default_template_expand(),
  styles = s,
  arguments = a,
  functions = f
}

