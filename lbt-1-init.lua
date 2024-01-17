--
-- We act here on the global table `lbt`.
-- It is assumed to exist (and be empty).
--

--------------------------------------------------------------------------------
-- system, const, var   [global data]
-- init                 [reset the data for each expansion]
--------------------------------------------------------------------------------

-- lbt.system contains data shared for the whole Latex document.
--
-- It is reset using lbt.init.reset_system() once during \usepackage{lbt}.
--
-- In here, we keep track of all templates that are available for use, and
-- any styles the author wants to override globally. And persistent counters
-- and data.
--
-- Furthermore, we know whether draft mode is enabled, and which log channels
-- are to be included in the logfile.
lbt.system = {}

-- lbt.const contains constant data used by a single expansion.
--
-- It is reset using lbt.init.reset_const() every time a new expansion begins 
--
-- The constants are a list of lines typed by the author in the `lbt`
-- environment, and a list of source templates to search when trying to resolve
-- a token.
lbt.const = {}

-- lbt.var contains variable data (counters, general data like the current
-- heading) used by a single expansion, if the template code decides to use any.
--
-- It is reset using lbt.init.reset_var() every time a new expansion begins.
lbt.var = {}

-- lbt.init contains two functions for resetting lbt.const and lbt.init, so
-- they are in a state ready for a new expansion to take place.
lbt.init = {}

--------------------------------------------------------------------------------
-- Functions to perform initialisation (reset)
--
-- * specific:
--   - init_system()
--   - reset_const()
--   - reset_var()
--
-- * purposeful:
--   - initialize_all()        [called once, in lbt.sty]
--   - reset_const_var()       [for a new expansion]
--   - soft_reset_system()     [good for testing -- see lbt.api.reset_global_data()]
--------------------------------------------------------------------------------

lbt.init.initialize_all = function ()
  lbt.init.init_system()
  lbt.init.reset_const()
  lbt.init.reset_var()
end

lbt.init.reset_const_var = function ()
  lbt.init.reset_const()
  lbt.init.reset_var()
end

-- Warning: only call this once, as it wipes out builtin template.
-- See: lbt.init.soft_reset_system()
lbt.init.init_system = function ()
  -- Collection of templates that are loaded and ready to use.
  -- Type: pl.Map
  -- Mapping from template name to template register entry.
  -- For example:
  --   'CourseNotes' --> { path = '/path/to/CourseNotes.lua',
  --                       td   = { name = 'CourseNotes',
  --                                desc = '...',
  --                                functions = { ... }
  --                                ...}}
  -- This data is global (system-wide) because template data is read-only,
  -- and once a template has been referenced (and hence loaded) once, it is
  -- available for use from then on.
  lbt.system.template_register = pl.Map()
  -- Style mapping that the author wants applied in every template expansion.
  -- Set via (for example) \lbtStyles{Q.color purple :: MC.alphabet roman}
  lbt.system.document_wide_styles = pl.Map()
  -- If we have a system-wide draft mode, then only content labeled !DRAFT
  -- will be expanded.
  -- Set via \lbtDraftMode{true}
  lbt.system.draft_mode       = false
  -- Persistent counters and data.
  lbt.system.persistent_counters = {}
  lbt.system.persistent_data = {}
  -- By default, we log only channels 1-3 (ERROR, WARN, INFO)
  lbt.system.log_channels     = pl.List{1,2,3}
  -- Each expansion has an autoincrementing ID so that log messages can be
  -- coherent and debug files can be written. We start at 100 so it is a
  -- three-digit number.
  lbt.system.expansion_id = 100
end

-- Reset the lbt.system table to a clean but workable state.
--  * clear document-wide styles
--  * clear persistent counters and data
--  * leave builtin templates alone but remove any others
--  * leave draft mode as it was
--  * set log channels to the default 1,2,3
lbt.init.soft_reset_system = function ()
  lbt.system.document_wide_styles = pl.Map()
  for name, t in lbt.system.template_register:iter() do
    if name:startswith('lbt.') then
      -- do nothing
    else
      -- remove it
      lbt.system.template_register[name] = nil
    end
  end
  lbt.system.log_channels = pl.Set{1,2,3}
  lbt.system.persistent_counters = {}
  lbt.system.persistent_data = {}
end

lbt.init.reset_const = function ()
  -- Every line between \begin{lbt} and \end{lbt} goes into this list for
  -- processing by lbt.fn.parsed_content(). Line continuation with » is handled
  -- by the code that populates this list.
  lbt.const.author_content = pl.List()
end

lbt.init.reset_var = function ()
  -- Just like normal Latex, templates often need access to counters, for
  -- question numbers, sub-question numbers, etc.
  -- lbt.api.reset_counter('q') etc.
  lbt.var.counters = {}
  -- Similar to counters but more general, _data_ might store items like
  -- the current heading, so that a running header can be implemented.
  -- lbt.api.data_get(...); lbt.api.data_set(...)
  lbt.var.data = {}
  -- Current register values and expiry times.
  lbt.var.registers = pl.Map()
  -- We need to know what token number we are on so that we know when registers
  -- expire. Ideally this would be a local variable but it's too much trouble
  -- as it would be passed to functions and back again.
  -- Start at zero and increment when we are about to act on a token.
  -- Do not increment if the "token" is a register allocation.
  lbt.var.token_count = 0
end



--------------------------------------------------------------------------------
-- api          [functions called by Latex or templates]
-- fn           [functions supporting the API]
-- util         [functions useful in template code]
-- err          [centralised error messages]
-- test         [unit testing]
--------------------------------------------------------------------------------

-- lbt.api will contain functions called by the LaTeX commands in the package.
-- Also functions called by template code.
-- For example: author_content_collect, author_content_emit_latex,
--              counter_reset, style
lbt.api = {}


-- lbt.fn will contain functions used for the core implementation.
-- For example: parsed_content, latex_expansion
lbt.fn = {}


-- lbt.util will contain functions that assist template code.
-- For example: wrap_braces, extract_option_argument
-- Note: it contains useful functions for the implementation as well,
-- like print_tex_lines.
-- Arguably the two concerns should be separate, and the latter functions
-- might migrate to fn.impl in due course.
lbt.util = {}


-- lbt.err contains functions that assist in error handling.
lbt.err = {}


-- lbt.test contains unit tests.
lbt.test = {}

