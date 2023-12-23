-- +----------------------------------------+
-- | Template: lbt.CourseNotes              |
-- |                                        |
-- | Purpose: Questions, hints, answers for |
-- |          worksheets, exams, ...        |
-- +----------------------------------------+

local F = string.format

local f = {}

local function expand (pc)
  return F([[\textbf{CourseNotes}]])
end

lbt.api.register_template {
  name      = 'lbt.CourseNotes',
  desc      = 'Title page, sections, running headings',
  sources   = {"lbt.Questions"},
  init      = lbt.api.default_template_init,
  expand    = lbt.api.default_template_expand,
  functions = f
}

