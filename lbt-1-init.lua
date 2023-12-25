--
-- We act here on the global table `lbt`.
-- It is assumed to exist (and be empty).
--

--------------------------------------------------------------------------------
-- system, const, var   [global data]
-- init                 [reset the data for each expansion]
--------------------------------------------------------------------------------

-- lbt.system contains data shared for the whole Latex document.
-- It is initialised here because it only needs to happen once.
lbt.system = {
  template_register = {},      -- templates that are loaded and ready to use
                               --     (dictionary: name -> table)
  draft_mode       = false,
  debug_mode       = false,
}

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

lbt.init.reset_const = function ()
  -- Every line between \begin{lbt} and \end{lbt} goes into this list for
  -- processing by lbt.fn.parsed_content(). Line continuation with » is handled
  -- by the code that populates this list.
  lbt.const.author_content = pl.List()
  -- The various tokens within a template may have style information that
  -- informs the Latex output (think CSS to HTML). The consolidated dictionary
  -- of style information needs to be global because every template function
  -- needs access to it via, for example, lbt.api.style('Q.color'). It is too
  -- onerous for every template function to receive it as a parameter.
  lbt.const.styles = nil
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

