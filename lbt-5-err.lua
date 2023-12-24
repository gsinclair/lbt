--
-- We act on the global table `lbt` and populate its subtable `lbt.err`.
--

lbt.err.quit_with_error = function(msg, ...)
  message = string.format(msg, ...)
  traceback = debug.traceback()
  debug_message = "\n\n\n" .. message .. "\n\n\n" .. debug.traceback() .. "\n\n\n"
  lbt.log("An error occurred (message below). See debug file for more information.")
  lbt.log(message)
  lbt.dbg(debug_message)
  print(debug_message)
  os.exit()
end

-- local E = lbt.err.quit_with_error
local E = function(msg, ...)
  message = string.format(msg, ...)
  debug_message = "\n\n\n" .. message .. "\n\n\n" .. debug.traceback() .. "\n\n\n"
  lbt.log("An error occurred (message below). See debug file for more information.")
  lbt.log(message)
  lbt.dbg(debug_message)
  error(message, 3)
end

--------------------------------------------------------------------------------

lbt.err.E001_internal_logic_error = function(details)
  details = details or "(no details provided)"
  if details then
    E("Internal logic error: %s", details)
  else
    E("Internal logic error: (no details provided)")
  end
end

lbt.err.E100_invalid_token = function(line)
  E("E100: Invalid token encountered in content line:\n  <<%s>>", line)
end

lbt.err.E101_line_out_of_place = function(line)
  E("E101: Line out of place (not contained in @META or +BODY or similar):\n  <<%s>>", line)
end

lbt.err.E200_no_template_for_name = function(name)
  E("E200: No template for the given name <%s>", name)
end

lbt.err.E213_failed_template_load = function(path, error_details)
  E("E213: Failed to load template:\n * path: %s\n * msg: %s", path, error_details)
end

lbt.err.E215_invalid_template_details = function(td, error_details)
  message = [[
E215: Invalid template details. An attempt was made to register a template
with a table that has missing or invalid information. A Lua file that
describes a template should have at the bottom:
  
  return {
    name = <string>,
    desc = <string>,
    sources = <list (table) of strings>,    # name of each dependency
    init = <function>,                      # can use lbt.api.template_default_init
    expand = <function>,                    # can use lbt.api.template_default_expand
    functions = <table of functions>
  }

The error detected in your template description was:
  %s

Your template description is below.

%s]]
  E(message, error_details, pl.pretty.write(td))
end
