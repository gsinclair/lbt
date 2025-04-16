-- An ExpansionContext object lives for the duration of one LBT document.
-- It is created prior to calling lbt.fn.latex_expansion_of_parsed_content(pc)
-- and is stored in the global variable lbt.const.current_expansion_context.
--
-- It serves to:
--  * resolve opcodes
--  * look up global and local opargs

local ExpansionContext = {}
ExpansionContext.mt = { __index = ExpansionContext }

function ExpansionContext.new(args)
  assert(args.pc and args.template and args.sources)
  local o = {
    template = args.template,
    sources = args.sources,
    opargs_global = lbt.system.opargs_global,
    opargs_local  = lbt.core.DictionaryStack.new(),
    opcode_cache  = {},
    oparg_cache   = {},
  }
  o.opargs_local:push(args.pc:opargs_local())
  setmetatable(o, ExpansionContext.mt)
  return o
end

local _resolve_opcode_impl_nocache = function(opcode, sources)
  for s in sources:iter() do
    -- Each 'source' is a template object, with properties like 'functions'
    -- and 'arguments' and 'default_options' and ...
    if s.functions[opcode] then
      return {
        opcode  = opcode,
        fn      = s.functions[opcode],
        source_name = s.name,
        spec = {
          posargs = s.arguments[opcode],
          opargs  = s.default_options[opcode],
          kwargs  = s.kwargs[opcode],
        },
        -- TODO: change names inside templates to posargs, opargs, kwargs.
        -- That's a simple change that touches many files.
      }
    end
  end
  -- No token function found :(
  return nil
end

local _resolve_opcode_impl_cache = function(opcode, cache, sources)
  if cache[opcode] == nil then
    local result = _resolve_opcode_impl_nocache(opcode, sources)
    cache[opcode] = result
  end
  return cache[opcode]
end

-- This will be used wherever ocr('Q') is currently used. It returns all possible
-- information about the opcode.
--   We implement the starred logic here, which is messy but important. To illustrate,
-- consider the examples:
--  * TEXT is an unstarred command implemented by the function TEXT
--  * TEXT* is a starred command implemented by TEXT with the added oparg starred = true
--  * QQ is an unstarred command implemented by the function QQ
--  * QQ* is on the surface a starred command, but it is implemented by the function QQ*
--    (and it does not have starred = true set)
--  * PQRST is non-existed
--  * PQRST* is also non-existent, but we need to look for PQRST to be sure
--
-- Here is some further description from the pre-refactoring code. It refers to ocr(...)
-- which is now replaced with ExpansionContext:resolve_opcode.
--
--     The opcode TEXT* will result in the same opcode_function as TEXT, but the oparg
--     'starred' needs to be set. But there are permutations. Consider TEXT*, QQ* and
--     PART*.
--
--     ocr('TEXT*') will return nil because it is not registered as its own command.
--     So we check ocr('TEXT') and get a result. Further, the TEXT function supports
--     the oparg 'starred' (default false, of course). So we now have our function and
--     need to communicate that 'starred = true' needs to be registered in the opargs.
--
--     ocr('QQ*') will return a result because it is implemented directly. So we don't do
--     anything special.
--
--     ocr('PART*') will return nil, and ocr('PART') will return a result. However, the
--     opargs for PART do not include 'starred', so there is in fact no implementation
--     for PART*, and we return nil.
function ExpansionContext:resolve_opcode(opcode)
  local starred, unstarred, result
  local lookup = function(x)
    return _resolve_opcode_impl_cache(x, self.opcode_cache, self.sources)
  end
  if opcode:endswith('*') then
    starred = opcode
    unstarred = opcode:sub(1,-2)
  else
    starred = nil
    unstarred = opcode
  end
  -- Example: TEXT or QQ* (we find the right details right away)
  result = lookup(opcode)
  if result then return result end
  -- If we found nothing, it's only worth continuing if a starred opcode was given.
  if not starred then
    return nil
  end
  -- Example: TEXT*
  result = lookup(unstarred)
  if result then
    -- What we got back does not have 'starred = true' in it
    -- We operate on a copy so as not to affect the cached value.
    result = pl.tablex.copy(result)
    result.starred = true
    -- But we can cache this for later so that TEXT* is found quickly.
    self.opcode_cache[starred] = result
    return result
  end
  -- Example: PQSRT*
  if not result then
    -- There was simply no match, starred or unstarred.
    return nil
  end
  lbt.err.E001_internal_logic_error("shouldn't reach here")
end

-- -- Given an opcode like 'SECTION' and an opcode resolver (ocr), return
-- --   { opcode_function = ..., argspec = ..., starred = true (perhaps) }
-- -- If no function exists for the opcode, return nil.
-- -- (The opcode resolver will try the current template, then any sources, then...)
-- -- All this is handled by the ocr; we don't implement any smart logic, yet.
-- --
-- --
-- -- The code is messy, but I don't really see any choice.
-- --
-- lbt.fn.impl.resolve_opcode_function_and_argspec = function (opcode, ocr, ol)
--   lbt.debuglog('resolve_opcode_function_and_argspec:')
--   lbt.debuglog('  opcode = %s', opcode)
--   lbt.debuglog('  ocr    = %s', ocr)
--   lbt.debuglog('  ol     = %s', ol)
--   local x, base
--   x = ocr(opcode)
--   if x then
--     return x               -- First time's a charm, like SECTION or QQ*
--   end
--   -- Maybe this is a starred opcode?
--   if opcode:endswith('*') then
--     base = opcode:sub(1,-2)
--     x = ocr(base)
--     if x == nil then
--       return nil           -- There is no base opcode with potential star, like PQXYZ*
--     else
--       -- There is potential but we need to check.
--       if ol:_has_key(base, 'starred') then
--         -- Bingo! We have something like SECTION*
--         x.starred = true
--         return x
--       else
--         -- Boo. We have something like PART*, where PART does not allow for a star
--         return nil
--       end
--     end
--   else
--     -- This is not a starred opcode, like PQXYZ, so we are out of luck.
--     return nil
--   end
-- end

-- To resolve an oparg, we need to look at options set in this LBT document and
-- options set in the Latex document. Both of these are a DictionaryStack.
--   Options specified in a command are not seen here. That is handled inside
-- OptionLookup, which is inside Command. The principal purpose of this function
-- is to support OptionLookup. However, there are cases where an oparg needs to be
-- resolved that is not connected to a command. It could be in the general template
-- expansion code, and it could be in an LBT macro.
--   Only a qualified key can be used for lookup at this level.
--   We cache the result of our lookup.
--   Thus, the sequence is:
--     1. Check that we have a qualified key.
--     2. See if the key is in the cache.
--     3. Check the oparg_local stack.
--     4. Check the oparg_global stack.
--     5. Return nil as the oparg was not found.
function ExpansionContext:resolve_oparg(qkey)
  -- (1)
  lbt.core.oparg_check_qualified_key(qkey)
  local value
  -- (2)
  value = self.cache[qkey]
  if value then return value end
  -- (3)
  value = self.oparg_local:lookup(qkey)
  if value then return self:cache_store(qkey, value) end
  -- (4)
  value = self.oparg_global:lookup(qkey)
  if value then return self:cache_store(qkey, value) end
  -- (5)
  return nil
end

-- If an oparg_local gets updated mid-document, the cache needs to be invalidated.
-- We could clear just the relevant key, but for now let's just clear the whole
-- thing. Mid-document updates will be rare anyway.
function ExpansionContext:clear_oparg_cache()
  self.oparg_cache = {}
end

lbt.fn.ExpansionContext = ExpansionContext
