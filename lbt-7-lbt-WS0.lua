-- +---------------------------------------+
-- | Template: lbt.WS0                     |
-- |                                       |
-- | Purpose: Simple worksheet with title, |
-- |          course and teacher notes.    |
-- +---------------------------------------+

-- Note to readers: this is an explicit template with an expand function
-- but no additional functionality of its own.

local F = string.format

local f = {}

local expand = function(pc)
  return "\emph{WS0}"
end

lbt.api.register_template {
  name      = 'lbt.WS0',
  sources   = {"lbt.Questions"},
  init      = lbt.api.default_template_init,
  expand    = expand,
  functions = f
}

