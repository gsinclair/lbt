--
-- We act on the global table `lbt` and populate its subtable `lbt.err`.
--

lbt.err.quit_with_error = function (msg, ...)
  local message = string.format(msg, ...)
  local text = pl.stringio.create()
  text:write('\n\n\n')
  text:write('******************************************************* LBT \n')
  text:write('  An error has occurred -- details below\n')
  text:write('  The process will exit\n')
  text:write('******************************************************* LBT \n')
  text:write('\n\n\n')
  text:write(message)
  text:write('\n\n\n')
  text:write(debug.traceback())
  text:write('\n')
  text = text:value()
  lbt.log(1, text)
  print(text)
  os.exit()
end

local E = lbt.err.quit_with_error
local F = string.format

--------------------------------------------------------------------------------

lbt.err.E001_internal_logic_error = function(details)
  details = details or "(no details provided)"
  if details then
    E("Internal logic error: %s", details)
  else
    E("Internal logic error: (no details provided)")
  end
end

-- no longer needed
lbt.err.E100_invalid_token = function(line)
  E("E100: Invalid token encountered in content line:\n  <<%s>>", line)
end

lbt.err.E102_invalid_pragma = function(p)
  E("E100: Invalid pragma encountered:\n  <<%s>>", p)
end

-- no longer needed
lbt.err.E101_line_out_of_place = function(line)
  E("E101: Line out of place (not contained in [@META] or [+BODY] or similar):\n  <<%s>>", line)
end

lbt.err.E110_unable_to_parse_content = function(text, pos)
  local message = [[

  (lbt) *** Attempt to parse LBT content failed ***'
  (lbt) position: %d    text: %s'

%s

  (lbt) end of report'

]]
  E(message, pos, text:sub(pos,pos+50), text)
end

-- no longer needed
lbt.err.E105_dictionary_key_without_value = function(line)
  E("E105: Content dictionary has key with no value:\n  <<%s>>", line)
end

lbt.err.E200_no_template_for_name = function(name)
  E("E200: No template for the given name <%s>", name)
end

lbt.err.E206_cant_form_list_of_sources = function (name)
  E("E206: Can't form a consolidated list of sources.\n"..
    "      The problem is the template named <%s>.", name)
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
    name      = <string>,
    desc      = <string>,
    sources   = <list (table) of strings>,   # name of each dependency
    init      = <function>,                  # can be omitted
    expand    = <function>,                  # can be omitted
    functions = <table of functions>,
    arguments = <table of arg specs>,        # can be omitted
    styles    = <table of styles>            # can be omitted
  }

The error detected in your template description was:
  %s

Your template description is below.

%s]]
  E(message, error_details, pl.pretty.write(td))
end

lbt.err.E301_default_expand_failed_no_body = function()
  E("E301: Can't expand content -- there is no BODY section")
end

lbt.err.E302_content_list_not_found = function (pc, key)
  lbt.assert_table(1, pc)
  E([[E302: While expanding a template, an attempt was made to access a
content list, but it doesn't exist.
  Template:     %s
  Content list: %s]], lbt.fn.pc.template_name(pc), key)
end

lbt.err.E303_content_dictionary_not_found = function (pc, key)
  E([[E302: While expanding a template, an attempt was made to access a
content dictionary, but it doesn't exist.
  Template:     %s
  Dictionary:   %s]], lbt.fn.pc.template_name(pc), key)
end

lbt.err.E343_invalid_template_expansion_result = function(x)
  E("E343: Invalid template expansion result. Expected a string; got " .. type(x))
end

lbt.err.E387_style_not_found = function (key)
  E("E387: No value for style key <%s>", key)
end

lbt.err.E402_invalid_alphabet = function (alph)
  E("E402: Invalid alphabet <%s> for conversion.\n"..
    "      Options are latin | Latin | roman | Roman", alph)
end


lbt.err.E159_macro_run_error = function (format, ...)
  local details = F(format, ...)
  local errormsg = F('Failed to run a macro (presumably defined with \\lbtDefineLatexMacro)\nDetails: %s', details)
  E(errormsg)
end

lbt.err.E158_macro_define_error = function (format, ...)
  local details = F(format, ...)
  local errormsg = F('Failed to define a macro (presumably defined with \\lbtDefineLatexMacro)\nDetails: %s', details)
  E(errormsg)
end

lbt.err.E109_invalid_macro_define_spec = function (arg)
  local errormsg = F('LBT attempt to define a Latex macro failed: %s', arg)
  E(errormsg)
end

lbt.err.E998_content_meta_value_missing = function (key)
  local errormsg = F("Expected to find key '%s' in META, but didn't", key)
  E(errormsg)
end

lbt.err.E976_no_META_field = function (pc)
  local errormsg = F("No META field in current parsed content", key)
  E(errormsg)
end

lbt.err.E318_invalid_register_assignment_nargs = function (x)
  E('When calling STO to set a register, you need to give three arguments:\n'..
    '  name, ttl, definition')
end

lbt.err.E325_invalid_return_from_template_function = function (token, result)
  E('When calling function for token %s, the result was invalid\nResult: %s', token, lbt.pp(result))
end
