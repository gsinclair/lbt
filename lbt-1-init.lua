--
-- We act here on the global table `lbt`.
-- It is assumed to exist (and be empty).
--

-- lbt.system contains data shared for the whole Latex document.
-- It is initialised here because it only needs to happen once.
lbt.system = {
  template_register = {},      -- templates that are loaded and ready to use
                               --     (dictionary: name -> table)
  draft_mode       = false,
  debug_mode       = false,
}

-- lbt.const contains constant data used by a single expansion.
-- It is reset using lbt.init.reset_const() every time a new expansion begins 
lbt.const = {
  author_content = pl.List(), -- lightly processed strings go into this list for parsing
  styles  = nil               -- consolidated styles for token expansion
}

-- lbt.var contains variable data used by a single expansion.
-- It is reset using lbt.init.reset_var() every time a new expansion begins.
lbt.var = {
  counters    = {},   -- like a Latex counter: question number, item number, ...
  data        = {},   -- generalised counter: current heading, ...
}

-- lbt.api will contain functions called by the LaTeX commands in the package.
-- For example: process, reset_counter, emit_tex.
lbt.api = {}

-- lbt.fn will contain functions used for the core implementation.
lbt.fn = {}

-- lbt.util will contain functions that assist in implementation.
lbt.util = {}

-- lbt.err will contain functions that assist in error handling.
lbt.err = {}

-- lbt.test will contain functions that assist in testing.
lbt.test = {}

--
-- Functions to reset lbt.const and lbt.var.
--

lbt.init = {
  reset_const = function()
    lbt.const = {
      author_content = pl.List(),
      styles  = nil
    }
  end,
  reset_var = function()
    lbt.var = {
      counters  = {},
      data      = {},
    }
  end
}

