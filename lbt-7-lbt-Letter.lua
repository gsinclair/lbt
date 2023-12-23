-- +----------------------+
-- | Template: lbt.Letter |
-- +----------------------+

local F = string.format

local f = {}

local function expand (pc)
  return F([[\textbf{Letter}]])
end

lbt.api.register_template {
  name      = 'lbt.Letter',
  desc      = 'From/to name and address, salutation, etc.',
  sources   = {},
  init      = lbt.api.default_template_init,
  expand    = lbt.api.default_template_expand,
  functions = f
}

