-- +---------------------------------------+
-- | First we define a bunch of functions. |
-- +---------------------------------------+

local F = string.format
local T = lbt.util.string_template_expand

local f = {}   -- functions
local a = {}   -- number of arguments
local m = {}   -- macros
local op = {}  -- opargs

---------- DB and supporting functions ----------

local db_err = function(fmt, ...)
  lbt.err.E002_general('(DB) '..fmt, ...)
end

local db_check_valid_label = function(label)
  if label:match('^[%a%d_-]+$') then
    return label
  else
    db_err("invalid label: '%s'", label)
  end
end

local db_get_root_db = function()
  local db0 = lbt.api.data_get('lbt-db', {})
  lbt.api.data_set('lbt-db', db0)   -- Ensure we have at least an empty table stored.
  return db0
end

local db_retrieve = function(label)
  local db0 = db_get_root_db()
  if not db0[label] then
    db0[label] = {}
  end
  return db0[label]
end

local db_init = function(label)
  local db0 = db_get_root_db()
  if db0[label] then
    db_err("cannot initialise db for label '%s' because it already exists", label)
  else
    db0[label] = pl.Map()
    return true
  end
end

local db_parse_input_text = function(text)
  -- Return a table with indices and (if provided) keys.
  -- The values in the table are chunks of text between '% --------' lines.
  -- If a '% key: ...' line is the first in a chunk, it is stripped.
  local chunks = pl.List { text:splitv("%% %-+%s*\n") }
  local extract_key_and_chunk = function(lines)
    local key = lines[1]:match("^%%%s+key:%s+(.+)")
    if key then
      return key, lines:slice(2,-1):join('\n')
    else
      return nil, lines:join('\n')
    end
  end
  local parse_chunk = function(chunk)
    local lines = pl.List(chunk:rstrip():splitlines())
    local key, chunk = extract_key_and_chunk(lines)
    return key, chunk
  end
  local result = {}
  local index = 1
  for c in chunks:iter() do
    local key, x = parse_chunk(c)
    result[index] = x
    if key then
      result[key] = x
    end
    index = index + 1
  end
  return result
end

local db_process_text_into_latex = function(text)
  local x = lbt.parser.parse_commands(text)
  if x.ok then
    local items = lbt.fn.latex_for_commands(x.commands)
    return items:join('\n\n')  -- is there a util function?
  else
    lbt.err.E002_general('(DB) could not parse commands:\n'..text)
  end
end

local db_functions = {
  loadfile = function(t)
    if t.nargs ~= 1 then db_err('loadfile needs one argument') end
    local path = t.args[1]
    local file = io.open(path, 'r')
    if file then
      local contents = file:read('*a')
      file:close()
      local data = db_parse_input_text(contents)
      -- Having loaded the file, we need to replace the current contents of the target
      -- database. It is presumably empty anyway, but just in case.
      pl.tablex.clear(t.db)
      pl.tablex.update(t.db, data)
    else
      db_err("unable to load file: '%s'", path)
    end
  end,

  index = function(t)
    if t.nargs ~= 1 then db_err('index needs one argument') end
    local n = tonumber(t.args[1])
    local N = #t.db
    if n < 0 then
      -- Negative indexing from the end, like Python. db[-1] == db[N]
      n = n + 1 + N
    end
    if n < 1 or n > N then
      lbt.util.template_error_quit('vec index error: %d', n)
    end
    local text = t.db[n]
    -- -- Now I have the entry from the database, I need to get LBT to process it.
    -- -- For now, just return number of characters.
    -- return text:sub(1,10)
    return db_process_text_into_latex(text)
  end,

  key = function(t)
    if t.nargs ~= 1 then db_err('index needs one argument') end
    local k = t.args[1]
    local text = t.db[k]
    if text == nil then
      lbt.util.template_error_quit('vec key error: %s', k)
    end
    return db_process_text_into_latex(text)
  end
}

a.DB = '2+'
op.DB = { showkey = false, order = 'index' }
f.DB = function(n, args, o)
  if args[1] == 'init' then
    local label = db_check_valid_label(args[2])
    db_init(label)
    return '{}'
  else
    local label = db_check_valid_label(args[1])
    local command = args[2]
    local func = db_functions[command] or db_err("no function implementation for '%s'", command)
    local db = db_retrieve(label)
    local result = func { db = db, nargs = n-2, args = args:slice(3,-1), opts = o }
    return result or '{}'
  end
end


return {
  name      = 'lbt.DataLoad',
  desc      = 'READCSV and DB commands to work with data stored externally',
  sources   = {},
  init      = nil,
  expand    = lbt.api.default_template_expander(),
  functions = f,
  posargs = a,
  opargs = op,
}
