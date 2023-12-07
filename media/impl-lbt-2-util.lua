--
-- We act on the global table `lbt` and populate its subtable `lbt.util`.
--

local assert_string = pl.util.assert_string

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
