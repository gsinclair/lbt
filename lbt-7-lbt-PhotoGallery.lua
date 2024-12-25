
-- +----------------------------------------+
-- | Template: lbt.PhotoGallery             |
-- |                                        |
-- | Purpose: Display a lot of photos, with |
-- |          captions, in an organised way |
-- +----------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand
local f = {}
local a = {}
local o = pl.List()

-- This provides the PHOTOGALLERY command only.

-- s.Article = { parstyle = 'skip',
--               parskip = '6pt plus 2pt minus 2pt',
--               parindent = '1em' }
-- o:append 'Article.parstyle = skip, Article.parskip = 6pt plus 2pt minus 2pt, Article.parindent = 1em'
o:append 'Article.parskip = 2pt plus 2pt minus 1pt, Article.parindent = 15pt'


local missing_keyword = function(x)
  error('Missing keyword in PHOTOGALLERY: ' .. x)
end

  local chatgpt = [[
  \begin{center}
      \begin{minipage}[t]{0.3\textwidth}
          \centering
          \includegraphics[width=\linewidth]{photo1.jpg}
          \caption*{Caption 1}
      \end{minipage}%
      \hfill
      \begin{minipage}[t]{0.3\textwidth}
          \centering
          \includegraphics[width=\linewidth]{photo2.jpg}
          \caption*{Caption 2}
      \end{minipage}%
      \hfill
      \begin{minipage}[t]{0.3\textwidth}
          \centering
          \includegraphics[width=\linewidth]{photo3.jpg}
          \caption*{Caption 3}
      \end{minipage}
  \end{center}
]]


local caption_renderer = function (mark_yes, mark_no, feature_set)
  return function(caption)
    if #mark_yes > 0 or #mark_no > 0 then
      if mark_yes[caption] or feature_set[caption] then
        return F([[{\color{Aquamarine}\bfseries %s}]], caption)
      elseif mark_no[caption] then
        return F([[{\color{WildStrawberry}\bfseries %s \enspace \small\emoji{cross-mark}}]], caption)
      else
        return F([[{\color{gray}\bfseries %s}]], caption)
      end
    else
      return F([[\textbf{%s}]], caption)
    end
  end
end

-- TODO: use `opts` argument and include mark_yes and mark_no
--       Maybe pass a function that renders the caption, and let that function do the marking.
--       The function could default to what we have here.
-- local minipage_code = function (width, number, filename, max_height)
local minipage_code = function (opts)
  return T {
    [[\begin{minipage}[b]{!WIDTH!\textwidth}]],
    [[  \centering]],
    [[  \includegraphics[width=\linewidth,height=!HEIGHT!,keepaspectratio]{!FILENAME!} \\]],
    [[  !CAPTION!]],
    [[\end{minipage}]],
    values = {
      WIDTH    = opts.width or error(),
      HEIGHT   = opts.max_height or error(),
      FILENAME = opts.filename or error(),
      CAPTION  = opts.caption_renderer(opts.number or error()) or error(),
    }
  }
end

local slices = function (list, n)
  local result = pl.List()
  for i = 1, list:len(), n do
    result:append( list:slice(i, i+n-1) )
  end
  return result
end

local float_code = function (opts)
  return T {
    [[\begin{figure}[hp] ]],
    [[  \centering]],
    [[  \includegraphics[width=0.9\linewidth,height=0.9\textheight,keepaspectratio]{!FILENAME!} \\]],
    [[  !CAPTION!]],
    [[\end{figure}]],
    values = {
      FILENAME = opts.filename or error(),
      CAPTION  = opts.caption_renderer(opts.number or error()) or error()
    }
  }
end

local photo_number_summary = function(x)
  local fmt = [[{\color{gray}\small \hfill Ordinary photos: \textbf{%s} \quad\quad Feature photos: \textbf{%d} \hfill} \par \vspace{1em}]]
  return F(fmt, x.ordinary, x.feature)
end

-------------------------------------------------------------------------------
-- PHOTOGALLERY function
-------------------------------------------------------------------------------

a.PHOTOGALLERY = 0
o:append 'PHOTOGALLERY.showno = true'
f.PHOTOGALLERY = function(n, args, o, k)
  local folder        = k.folder      or missing_keyword('folder')
  local per_row       = k.per_row     or missing_keyword('per_row')
  local max_height    = k.max_height  or missing_keyword('max_height')
  local include       = k.include
  local exclude       = k.exclude
  local mark_yes      = k.mark_yes    or ''
  local mark_no       = k.mark_no     or ''
  local mark_yes_no   = k.mark_yes_no or ''
  local mark_no_yes   = k.mark_no_yes or ''
  local feature       = k.feature     or ''

  -- 1. Get a list of all image files, in the form { number = 37, filename = 'IMG_0037.jpg' }
  --    Product: all_files
  local filenames = pl.dir.getfiles(folder):sort()
  local image_extensions = pl.Set { 'jpg', 'jpeg' }   -- TODO: more extensions; case insensitive
  filenames = filenames:filter(function(fn)
    local ext = fn:match("%.([^%.]+)$")
    return image_extensions[ext]
  end)
  local all_files = pl.List()
  for fn in filenames:iter() do
    local n = fn:match("%d+")
    if n then
      n = tonumber(n)
      all_files:append { number = n, filename = fn }
    end
  end

  -- 2. Process optional include and exclude values.
  --    Product: all_files (modified)
  if include then
    include = lbt.util.parse_numbers_and_ranges(include)
    local include_set = pl.Set(include)
    local working_copy = pl.List(all_files)
    all_files = pl.List()
    for f in working_copy:iter() do
      if include_set[f.number] then
        all_files:append(f)
      end
    end
  end
  if exclude then
    exclude = lbt.util.parse_numbers_and_ranges(exclude)
    local exclude_set = pl.Set(exclude)
    local working_copy = pl.List(all_files)
    all_files = pl.List()
    for f in working_copy:iter() do
      if not exclude_set[f.number] then
        all_files:append(f)
      end
    end
  end

  local pnr = lbt.util.parse_numbers_and_ranges

  -- 3. Process optional mark values: mark_yes, mark_no, mark_yes_no, mark_no_yes
  --    Product: mark_yes and mark_no (sets).
  --    If option showno is false, this also affects all_files because we don't want
  --    to show the photos that are marked 'no'.
  local my  = pl.Set(pnr(mark_yes))
  local mn  = pl.Set(pnr(mark_no))
  local myn = pl.Set(pnr(mark_yes_no))
  local mny = pl.Set(pnr(mark_no_yes))
  mark_yes = pl.Set(); mark_no = pl.Set()
  if #myn > 0 then
    for f in all_files:iter() do
      local n = f.number
      if myn[n] then mark_yes[n] = true else mark_no[n] = true end
    end
  elseif #mny > 0 then
    for f in all_files:iter() do
      local n = f.number
      if mny[n] then mark_no[n] = true else mark_yes[n] = true end
    end
  else
    mark_yes = my
    mark_no  = mn
  end
  if o.showno == false then
    all_files = all_files:filter(function(f)
      return not mark_no[f.number]
    end)
  end

  -- 4. Process optional feature values.
  --    Product: ordinary_files, feature_files
  local feature_list = lbt.util.parse_numbers_and_ranges(feature)
  local feature_set = pl.Set(feature_list)
  local feature_files = pl.List()
  local ordinary_files = pl.List()
  for f in all_files:iter() do
    if feature_set[f.number] then
      feature_files:append(f)
    else
      ordinary_files:append(f)
    end
  end

  -- 5. Generate a minipage for each ordinary photo.
  --    And a float for each feature photo.
  --    Product: minipages: a list of { number, latex_code }
  --             floats:    a map of number -> latex_code
  local width = 1 / tonumber(per_row) - 0.05
  local minipages = pl.List()
  local cr = caption_renderer(mark_yes, mark_no, feature_set)
  for f in ordinary_files:iter() do
    local x = minipage_code {
      width = width, number = f.number, filename = f.filename,
      max_height = max_height, caption_renderer = cr
    }
    minipages:append( {f.number, x} )
  end
  local floats = pl.Map()
  for f in feature_files:iter() do
    floats[f.number] = float_code {
       number = f.number, filename = f.filename, caption_renderer = cr
    }
  end

  -- 6. Lay them out two per row or three per row or whatever.
  --    Featured photos are set between rows as a float.
  --    Output the number of photos at the beginning.
  local code = pl.List()
  code:append(photo_number_summary { ordinary = ordinary_files:len(), feature = feature_files:len() })
  local rows = slices(minipages, per_row)
  local feature_index = 1
  for row in rows:iter() do
    -- row is a small list of items like { 37, ...code... }
    -- It serves us to have the numbers and codes separately.
    local numbers = row:map(function (s) return s[1] end)
    local codes   = row:map(function (s) return s[2] end)
    -- Include any floats whose numbers we have passed.
    local highest_ordinary_number = numbers[1]
    while feature_list[feature_index] and feature_list[feature_index] < highest_ordinary_number do
      local x = floats[feature_list[feature_index]]  -- float code for this number
      code:append(x)
      feature_index = feature_index + 1
    end
    -- Now include this row of ordinary photos.
    code:append(codes:concat('\n\\hfill\n'))
  end

  -- 7. Done.
  return code:concat('\n\n')
end


return {
  name      = 'lbt.PhotoGallery',
  sources   = {},
  desc      = 'Display a grid of (many) photos',
  init      = nil,
  expand    = nil,
  functions = f,
  default_options = o,
  arguments = a,
  macros    = nil,
}
