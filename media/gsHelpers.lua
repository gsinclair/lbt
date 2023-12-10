-- String functions taken from telemachus/split [not the whole package]
--   * explode
--   * split

pprint = require "lib.pprint"

-- Return a table composed of the individual characters from a string.
local explode = function(str)
  local t = {}
  for i=1, #str do
    t[#t + 1] = string.sub(str, i, i)
  end

  return t
end

function trim(s)
   return s:gsub("^%s+", ""):gsub("%s+$", "")
end

function index_of(table, item)
  for i,v in ipairs(table) do
    if v == item then
      return i
    end
  end
  return -1
end

function table_contains(table, item)
  return index_of(table, item) >= 0
end

function table_keys(t)
  local result = {}
  for k,v in pairs(t) do
    table.insert(result, k)
  end
  return result
end

function basic_table_print(t, out)
  for k,v in pairs(t) do
    out:write(type(k), type(v), "\n")
  end
end

function pretty_print(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. pretty_print(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function table_to_string(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result..table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        else
            result = result.."\""..v.."\""
        end
        result = result..","
    end
    -- Remove leading commas from the result
    if result ~= "" then  -- better result if "{" ?
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end

function Set(elements)
  result = {}
  for _,x in ipairs(elements) do result[x] = true end
  return result
end

--- split(string, delimiter) => { results }
-- Return a table composed of substrings divided by a delimiter or pattern.
split = function(str, delimiter)
  -- Handle an edge case concerning the str parameter. Immediately return an
  -- empty table if str == ''.
  if str == '' then return {} end

  -- Handle special cases concerning the delimiter parameter.
  -- 1. If the pattern is nil, split on contiguous whitespace.
  -- 2. If the pattern is an empty string, explode the string.
  -- 3. Protect against patterns that match too much. Such patterns would hang
  --    the caller.
  delimiter = delimiter or '%s+'
  if delimiter == '' then return explode(str) end
  if string.find('', delimiter, 1) then
    local msg = string.format('The delimiter (%s) would match the empty string.',
                    delimiter)
    error(msg)
  end

  -- The table `t` will store the found items. `s` and `e` will keep
  -- track of the start and end of a match for the delimiter. Finally,
  -- `position` tracks where to start grabbing the next match.
  local t = {}
  local s, e
  local position = 1
  s, e = string.find(str, delimiter, position)

  while s do
    t[#t + 1] = string.sub(str, position, s-1)
    position = e + 1
    s, e = string.find(str, delimiter, position)
  end

  -- To get the (potential) last item, check if the final position is
  -- still within the string. If it is, grab the rest of the string into
  -- a final element.
  if position <= #str then
    t[#t + 1] = string.sub(str, position)
  end

  -- Special handling for a (potential) final trailing delimiter. If the
  -- last found end position is identical to the end of the whole string,
  -- then add a trailing empty field.
  if position > #str then
    t[#t + 1] = ''
  end

  -- Trim all matches.  [This code was not in the original.]
  for i = 1, #t do
    t[i] = trim(t[i])
  end

  return t
end


-- https://stackoverflow.com/questions/19326368/iterate-over-lines-including-blank-lines
function magiclines(s)
  if s:sub(-1) ~= "\n" then s = s.."\n" end
  return s:gmatch("(.-)\n")
end

function typecheck(o, t)
  assert(type(o) == t, F("Expected type: %s; object provided (%s) was %s", t, type(o), o))
end

--[[
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.

http://lua-users.org/wiki/SortedIteration
]]

function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    local key = nil
    --print("orderedNext: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        -- fetch the next value
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    return orderedNext, t, nil
end

