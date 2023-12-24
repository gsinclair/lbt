-- +-------------------------------------------------+
-- | Template: lbt.WS1                               |
-- |                                                 |
-- | Purpose: Similar to WS0 but with additional     |
-- |          structure: intro box, outro challenge. |
-- |                                                 |
-- | It builds on the idea of WS0 but can't actually |
-- | share code. You can make a copy and build on it |
-- | in your own way too if you like.                |
-- +-------------------------------------------------+

-- Note to readers: this is an explicit template with an expand function
-- but no additional functionality of its own.

local F = string.format

local f = {}


local expand = function(pc)
  return [[\emph{WS0}]]
end

return {
  name      = 'lbt.WS1',
  desc      = 'A worksheet like WS0 but with added structure (as an example)',
  sources   = {"lbt.Questions"},
  init      = lbt.api.default_template_init,
  expand    = expand,
  functions = f
}

