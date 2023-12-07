--
-- We act on the global table `lbt` and populate its subtable `lbt.util`.
--
-- NOTE this is very much in progress.
--

-- `tex.print` but with formatting. Hint: local-alias this to `P`.
function lbt.util.tex_print_formatted(text, ...)
  tex.print(string.format(text, ...))
end

-- Print each line in `str` with a separate call to `tex.print`.
function lbt.util.print_tex_lines(str)
  assert_string(1, str)
  for line in str:lines() do
    tex.print(line)
  end
end

-- Higher-order function for implementing simple template tokens.
-- This creates a Latex command that takes one argument and places \par afterwards.
-- e.g.   VSPACE = latex_cmd_par_1('vspace')
function lbt.util.latex_cmd_par_1(cmd)
  return function(arg)
    return F([[\%s{%s} \par]], cmd, arg)
  end
end

-- Higher-order function for implementing simple template tokens.
-- This creates a Latex command that takes one argument.
-- TODO remove this as it is not likely to be used.
-- e.g.   B = latex_cmd_1('textbf')
function lbt.util.latex_cmd_1(cmd)
  return function(arg)
    return F([[\%s{%s}]], cmd, arg)
  end
end

-- Higher-order function for implementing simple template tokens.
-- This creates a plain Latex command with no arguments.
-- e.g.   VFILL = latex_cmd('vfill')
function lbt.util.latex_cmd(cmd)
  return function(_)
    return F([[\%s]], cmd)
  end
end

