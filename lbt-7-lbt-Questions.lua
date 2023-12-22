-- +----------------------------------------+
-- | Template: lbt.Questions                |
-- |                                        |
-- | Purpose: Questions, hints, answers for |
-- |          worksheets, exams, ...        |
-- +----------------------------------------+

local F = string.format

local f = {}

f.Q = function(n, args)
  return F([[\textbf{Question }%d\enspace]], lbt.api.counter_get('q'))
end

lbt.api.register_template {

  name      = 'lbt.Questions',
  sources   = {},
  init      = function() lbt.api.reset_counter('q') end,
  expand    = lbt.api.default_template_expand,
  functions = f
}

