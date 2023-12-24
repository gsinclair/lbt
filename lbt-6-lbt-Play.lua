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

return {
  name      = 'lbt.Play',
  desc      = 'Actor lines, stage directions, etc.',
  sources   = {},
  init      = lbt.api.default_template_init,
  expand    = lbt.api.default_template_expand,
  functions = f
}

