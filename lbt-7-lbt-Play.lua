-- +--------------------------------------------+
-- | Template: lbt.Play                         |
-- |                                            |
-- | Purpose: Theatical play, with actor lines, |
-- |          stage descriptions, etc.          |
-- +--------------------------------------------+

local F = string.format

local f = {}

f.LINE = function(n, args)
  return F([[\textbf{An actor's line}]])
end

f.DIRECTION = function(n, args)
  return F([[\textbf{An actor's line}]])
end

lbt.api.register_template {
  name      = 'lbt.Play',
  sources   = {},
  init      = lbt.api.default_template_init,
  expand    = lbt.api.default_template_expand,
  functions = f
}

