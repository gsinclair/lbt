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

return {
  name      = 'lbt.CourseNotes',
  desc      = 'Title page, sections, running headings',
  sources   = {"lbt.Questions"},
  init      = nil,
  expand    = lbt.api.default_template_expander(),
  functions = f
}

