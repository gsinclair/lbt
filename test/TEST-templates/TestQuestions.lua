-- lbt project: test template
--
--
-- This template provides simple typesetting of questions, sub-questions and
-- multiple-choice options for worksheets, exams, etc.
--
-- It is a *test* template for the purposes of testing the lbt project,
-- in particular command options like vspace, color.
--
-- Styles provided:
--  * Q.pre               vertical space before a question  [a bedrock oparg]
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

local f = {}
local a = {}
local op = {}  -- opargs

local init = function()
  lbt.api.counter_reset('q')
end

a.Q = 1
op.Q = { pre = '12pt', color = 'blue' }
f.Q = function(n, args, o)
  lbt.api.counter_reset('qq')
  local col = o.color
  local q = lbt.api.counter_inc('q')
  return F([[\bsferies\color{%s}Question~%d}\enspace %s]], col, q, args[1])
end

a.QQ = 1
op.QQ = { alphabet = 'latin' }
f.QQ = function(n, args, o)
  local alph = o.alphabet
  local qq = lbt.api.counter_inc('qq')
  qq = lbt.util.number_in_alphabet(qq, alph)
  return F([[(%s)~%s]], qq, args[1])
end

a.MC = '1+'
op.MC = { alphabet = 'Latin' }
f.MC = function(n, args, o)
  local result = pl.List()
  local alph = o.alphabet
  for i,x in ipairs(args) do
    local line = F([[(MC %s) \quad %s\\]],
      lbt.util.number_in_alphabet(i, alph), x)
    result:append(line)
  end
  return result
end

return {
  name = 'TestQuestions',
  desc = 'A test template for the lbt project',
  sources = {},
  init = init,
  expand = lbt.api.default_template_expander(),
  opargs = op,
  posargs = a,
  functions = f
}

