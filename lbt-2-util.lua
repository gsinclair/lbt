--
-- We act on the global table `lbt` and populate its subtable `lbt.util`.
--
-- NOTE this is very much in progress.
--
-- The main intention of lbt.util.* is to be useful to people writing template
-- code. Given that, it arguably should have a better name.

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

function lbt.util.wrap_braces(x)
  return '{' .. x .. '}'
end

-- name:      name of the command
-- nargs:     exact number of arguments it takes
-- paragraph: 'par' if you want a \par afterwards; nil otherwise
-- 
-- Examples:
--   latex_cmd('vspace', 1, 'par')
--   latex_cmd('vfill', 0)
function lbt.util.latex_cmd(name, nargs, paragraph)
  return function(n, args)
    if n ~= nargs+1 then
      return 'nargs', ''..nargs+1
    end
    local cmd = args[1]
    if nargs == 1 then
      result = F([[\%s]], cmd)
    else
      arguments = args:slice(2,-1):map(lbt.util.wrap_braces)
      result = F([[\%s%s]], cmd, arguments)
    end
    if paragraph == 'par' then
      result = result .. [[ \par]]
    end
    return result
  end
end

-- Given arguments to a token, see if the first one is an "options" argument.
-- Return the options argument (or nil) and the rest of the arguments.
-- e.g.
--   [a=5,b=7], X, Y, Z     -->  a=5,b=7   followed by   { X, Y, Z }
--   W, X, Y, Z             -->  nil       followed by   { W, X, Y, Z }
-- What signifies an options argument? It is surrounded by [].
--
-- Input: args (List)
function lbt.util.extract_option_argument (args)
  if args:len() == 0 then
    return nil, pl.List()
  else
    local first = args[1]
    if first:startswith('[') and first:endswith(']') then
      return first:sub(2,-2), args:slice(2,-1)
    else
      return nil, args
    end
  end
end
