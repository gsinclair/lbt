local F = string.format
local T = lbt.util.string_template_expand

return {
  name      = 'lbt.Doc.Chapter',
  desc      = 'A thin wrapper around a Latex \\chapter',
  sources   = {},
  init      = lbt.api.default_template_init,
  expand    = function (pc, ocr, ol)
    local title    = lbt.util.content_meta_or_error(pc, 'TITLE')
    local label    = lbt.util.content_meta_or_nil(pc, 'LABEL')

    return T {
      [[\chapter{!TITLE!} !LABEL!]],
      [[]],
      [[!BODY!]],
      values = {
        TITLE = title,
        LABEL = label and F([[\label{%s}]], label) or '',
        BODY  = lbt.util.latex_expand_content_list('BODY', pc, ocr, ol)
      }
    }
  end,
}
