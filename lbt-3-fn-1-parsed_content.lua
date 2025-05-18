
-- ParsedContent class
--
--  * ParsedContent.new(pc0, pragmas)
--  * pc:meta()
--  * pc:title()
--  * pc:dict_or_nil(name)
--  * pc:list_or_nil(name)
--  * pc:template_name()
--  * pc:template_object()
--  * pc:extra_sources()
--  * pc:local_options()
--  * pc:toString()       -- a compact representation
--------------------------------------------------------------------------------

-- Class for storing and providing access to parsed content.
-- The actual parsing is done in lbt.parser and the result (pc0) is fed in
-- here. We generate an index to facilitate lookups.
local ParsedContent = {}
ParsedContent.mt = { __index = ParsedContent }

-- {{{ object creation

local mkindex = function(pc0)
  local result = { dicts = {}, lists = {} }
  for _, x in ipairs(pc0) do
    if x.type == 'dict_block' then
      result.dicts[x.name] = x
    elseif x.type == 'list_block' then
      result.lists[x.name] = x
    end
  end
  return result
end

-- The idea of using metatables to build a class comes from Section 16.1 of the
-- free online 'Programming in Lua'.
function ParsedContent.new(pc0, pragmas)
  lbt.assert_table(1, pc0)
  lbt.assert_table(2, pragmas)
  local o = {
    type = 'ParsedContent',
    data = pc0,
    index = mkindex(pc0),
    pragmas = pragmas
  }
  setmetatable(o, ParsedContent.mt)
  return o
end

-- }}}

-- {{{ validation

function ParsedContent.validate(pc)
  -- We check that META and META.TEMPLATE are present.
  if pc:meta() == nil then
    lbt.err.E203_no_META_defined()      -- NOTE: This is redundant; meta() raises error anyway.
  end
  if pc:template_name() == nil then
    lbt.err.E204_no_TEMPLATE_defined()
  end
  return nil
end

-- }}}

-- {{{ accessors

-- Return a dictionary given a name. The actual keys and values are returned
-- in a table, not all the metadata that is stored in pc0.
function ParsedContent:dict_or_nil(name)
  local d = self.index.dicts[name]
  return d and d.entries
end

-- Return a list given a name. The actual values are returned in a table, not
-- all the metadata that is stored in pc0.
function ParsedContent:list_or_nil(name)
  local l = self.index.lists[name]
  return l and pl.List(l.commands)
end

-- Return the META dictionary block, or raise an error if it doesn't exist.
function ParsedContent:meta()
  local m = self:dict_or_nil('META')
  return m or lbt.err.E976_no_META_field()
end

-- Return the TITLE value from the META block, or '(no title)' if it doesn't exist.
function ParsedContent:title()
  return self:meta().TITLE or '(no title)'
end

function ParsedContent:template_name()
  return self:meta().TEMPLATE
end

function ParsedContent:template_object_or_error()
  local tn = self:template_name()
  local t = lbt.fn.Template.object_by_name(tn)
  return t
end

function ParsedContent:extra_sources()
  local sources = self:meta().SOURCES or ''
  if type(sources) == 'string' then
    return lbt.util.comma_split(sources)
  else
    lbt.err.E002_general('Trying to read template SOURCES and didn\'t get a string')
    return sources
  end
end

-- Inside META you can set, for example
--   OPTIONS   vector.format = tilde, QQ.prespace = 18pt
-- Here we grab that content, parse it, and return it as a dictionary.
-- Notes:
--  * if the user wrote ".d vector.format = tilde, QQ.prespace = 18pt"
--    then it is already parsed as a dictionary, so we return that
--  * if the user has set STYLES, that is old-fashioned and we exit
--    fast so they can fix it
--  * if we try to parse a dictionary and fail, we quit with error
function ParsedContent:opargs_local()
  if self:meta().STYLES then
    IX('Old-fashioned STYLES is set. Use OPTIONS instead', self:meta().STYLES)
  end
  local options = self:meta().OPTIONS
  -- TODO: we are type-checking `options` below. We should know the type.
  if type(options) == 'table' then
    return options
  elseif type(options) == 'string' then
    local text = options
    options = lbt.parser.parse_dictionary(text)
    return options or lbt.err.E946_invalid_option_dictionary_narrow(text)
  elseif options == nil then
    return pl.Map()
  else
    lbt.err.E001_internal_logic_error('OPTIONS not a string or table')
  end
end

-- }}}

lbt.fn.ParsedContent = ParsedContent
