-- +----------------------------------------+
-- | Template: LbtDoc                       |
-- |                                        |
-- | Purpose: Provide commands useful for   |
-- |          documenting LBT.              |
-- +----------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand
local f = {}
local a = {}
local op = {}
local m = {}

local impl = {}

a.LBTEXAMPLE = 1
op.LBTEXAMPLE = { horizontal = true, vertical = false, shrinkmargin = 'nil',
                  float = false, position = 'htbp' }
f.LBTEXAMPLE = function(_, args, o, kw)
  local lbt_code = impl.perform_substitution(kw.substitute, args[1])
  local result_latex = lbt.util.lbt_commands_text_into_latex(lbt_code)
  local overall_latex
  if o.vertical then
    overall_latex = F(impl.template_vertical, lbt_code, result_latex)
  elseif o.horizontal then
    overall_latex = F(impl.template_horizontal, lbt_code, result_latex)
  else
    lbt.util.template_error_quit('LBTEXAMPLE: need o.horizontal or o.vertical')
  end
  if o.shrinkmargin then
    overall_latex = T {
      [[\begin{adjustwidth}{-!SIZE!}{-!SIZE!}]],
      overall_latex,
      [[\end{adjustwidth}]],
      values = {
        SIZE = o.shrinkmargin
      }
    }
  end
  if o.float then
    return T { [[
        \begin{figure}[!POSITION!]
          !CONTENT!
          !CAPTION!
          \label{!LABEL!}
        \end{figure}
      ]],
      values = {
        POSITION = o.position,
        CONTENT = overall_latex,
        CAPTION = kw.caption and F([[\caption{%s}]], kw.caption) or '',
        LABEL = kw.label or error('no label'),
      }
    }
  else
    return overall_latex
  end
end

impl.template_horizontal = [[
  \vspace{1ex}
  \begin{minipage}[t]{0.45\textwidth}
    \begin{small}
      \begin{Verbatim}[formatcom=\color{NavyBlue}, frame=single, breaklines=true]
        %s
      \end{Verbatim}
    \end{small}
  \end{minipage}\hfill%%
  \begin{minipage}[t]{0.45\textwidth}
    \vspace{1ex}
    \begin{small}
      %s
    \end{small}
  \end{minipage}
]]

impl.template_vertical = [[
  \vspace{1em}
  \begin{small}
    \begin{Verbatim}[formatcom=\color{NavyBlue}, frame=single, breaklines=true]
      %s
    \end{Verbatim}
  \end{small}
  \begin{small}
    %s
  \end{small}
]]

impl.perform_substitution = function(sub_spec, text)
  if sub_spec == nil then return text end
  local bits = lbt.util.split(sub_spec, '/')
  local a, b = bits[2], bits[3]
  local x = text:gsub(a, b)
  return x
end

a.CODESAMPLE = 1
op.CODESAMPLE = { float = false, position = 'htbp' }
f.CODESAMPLE = function(n, args, o, kw)
  local verbatim_latex = T { [[
      \begin{Verbatim}[breaklines,fontsize=\small,xleftmargin=5mm,frame=single]
        !TEXT!
      \end{Verbatim}
    ]], values = {
      TEXT = args[1]
    }
  }
  if o.float then
    return T { [[
        \begin{figure}[!POSITION!]
          !CONTENT!
          !CAPTION!
          \label{!LABEL!}
        \end{figure}
      ]],
      values = {
        POSITION = o.position,
        CONTENT = verbatim_latex,
        CAPTION = kw.caption and F([[\caption{%s}]], kw.caption) or '',
        LABEL = kw.label or error('no label'),
      }
    }
  else
    return verbatim_latex
  end
end

return {
  name      = 'LbtDoc',
  sources   = {},
  desc      = 'Commands useful for documenting LBT.',
  init      = nil,
  expand    = nil,
  functions = f,
  opargs    = op,
  posargs   = a,
  macros    = m,
}

