
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

local minipage_code = function (width, number, filename, max_height)
  return T {
    [[\begin{minipage}[b]{!WIDTH!\textwidth}]],
    [[  \centering]],
    [[  \includegraphics[width=\linewidth,height=!HEIGHT!,keepaspectratio]{!FILENAME!} \\]],
    [[  \textbf{!CAPTION!}]],
    [[\end{minipage}]],
    values = {
      WIDTH    = width,
      HEIGHT   = max_height,
      FILENAME = filename,
      CAPTION  = number,
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

local float_code = function (number, filename)
  return T {
    [[\begin{figure}[tbph] ]],
    [[  \centering]],
    [[  \includegraphics[width=0.9\linewidth]{!FILENAME!} \\]],
    [[  \textbf{!CAPTION!}]],
    [[\end{figure}]],
    values = {
      FILENAME = filename,
      CAPTION  = number,
    }
  }
end

a.PHOTOGALLERY = 0
f.PHOTOGALLERY = function(n, args, o, k)
  local folder     = k.folder     or missing_keyword('folder')
  local per_row    = k.per_row    or missing_keyword('per_row')
  local max_height = k.max_height or missing_keyword('max_height')
  local include    = k.include
  local exclude    = k.exclude
  local feature    = k.feature    or ''

  -- 1. Get a list of all image files, in the form { number = 37, filename = 'IMG_0037.jpg' }
  --    Product: all_files
  local filenames = pl.dir.getfiles(folder):sort()
  local image_extensions = pl.Set { 'jpg', 'jpeg' }   -- TODO: more extensions; case insensitive
  filenames = filenames:filter(function(fn)
    local ext = fn:match("%.([^%.]+)$")
    return image_extensions[ext]
  end)
  filenames = filenames:slice(1,30)    -- NOTE: during devlopment only
  local all_files = pl.List()
  for fn in filenames:iter() do
    local n = fn:match("%d+")
    if n then
      n = tonumber(n)
      all_files:append { number = n, filename = fn }
    end
  end

  -- 2. Process optional include and exclude values.

  -- 3. Process optional feature values.
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

  -- 3. Generate a minipage for each ordinary photo.
  --    And a float for each feature photo.
  --    Product: minipages: a list of { number, latex_code }
  --             floats:    a map of number -> latex_code
  local width = 1 / tonumber(per_row) - 0.05
  local minipages = pl.List()
  for f in ordinary_files:iter() do
    local x = minipage_code(width, f.number, f.filename, max_height)
    minipages:append( {f.number, x} )
  end
  local floats = pl.Map()
  for f in feature_files:iter() do
    floats[f.number] = float_code(f.number, f.filename)
  end

  -- 4. Lay them out two per row or three per row or whatever.
  --    Featured photos are set between rows as a whole-page float.
  local code = pl.List()
  local rows = slices(minipages, per_row)
  local feature_index = 1
  for row in rows:iter() do
    -- row is a small list of items like { 37, ...code... }
    local numbers = row:map(function (s) return s[1] end)
    local codes   = row:map(function (s) return s[2] end)
    -- Include this row in the code.
    code:append(codes:concat('\n\\hfill\n'))
    -- Include any floats whose numbers we have passed.
    local highest_number = numbers[numbers:len()]
    while feature_list[feature_index] and feature_list[feature_index] < highest_number do
      local x = floats[feature_list[feature_index]]  -- float code for this number
      code:append(x)
      feature_index = feature_index + 1
    end
  end

  -- 5. Done.
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
