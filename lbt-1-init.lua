--
-- We act here on the global table `lbt`.
-- It is assumed to exist (and be empty).
--

-- lbt.system contains data shared for the whole Latex document.
-- It is initialised here because it only needs to happen once.
lbt.system = {
  templates = {},              -- templates that are loaded and ready to use
                               --     (dictionary: name -> table)
  templates_loaded = false,    -- flag
  draft_mode       = false,
  debug_mode       = false,
}

-- lbt.const contains constant data used by a single expansion.
-- It is reset using lbt.init.reset_const() every time a new expansion begins 
lbt.const = {
  pragmas   = pl.Set() -- affect operation: draft, ignore, debug
}

-- lbt.var contains variable data used by a single expansion.
-- It is reset using lbt.init.reset_var() every time a new expansion begins.
lbt.var = {
  author_content = pl.List(), -- raw strings go into this list for processing
  parsed_content = pl.List(), -- parsed content for emit_tex() to work on
  latex_content  = pl.List(), -- resulting Latex content
  counters  = {},     -- like a Latex counter: question number, item number, ...
  data      = {},     -- generalised counter: current heading, ...
  append_mode = nil,  -- implementation detail for parsing content
  current_key = nil,  -- implementation detail for parsing content
}

-- lbt.api will contain functions called by the LaTeX commands in the package.
-- For example: process, reset_counter, emit_tex.
lbt.api = {}

-- lbt.fn will contain functions used for the core implementation.
lbt.fn = {}

-- lbt.util will contain functions that assist in implementation.
lbt.util = {}

-- lbt.test will contain functions that assist in testing.
lbt.test = {}

--
-- Functions to reset lbt.const and lbt.var.
--

lbt.init = {
  reset_const = function()
    lbt.const = {
      pragmas   = {},
      draft_mode = false, -- flag
      debug_mode = false,
    }
  end,
  reset_var = function()
    lbt.var = {
      author_content = pl.List(),
      parsed_content = pl.List(),
      latex_content  = pl.List(),
      content   = {},
      counters  = {},
      data      = {},
      append_mode = nil,
      current_key = nil,
    }
  end
}

