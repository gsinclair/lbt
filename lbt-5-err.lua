--
-- We act on the global table `lbt` and populate its subtable `lbt.err`.
--

lbt.err.messages = {
  E001 = [[Internal logic error: DETAILS]],
  E002 = [[xxx]],
  E003 = [[xxx]],
  E004 = [[xxx]],
  E005 = [[xxx]],
}

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

local function msg(intcode)
  strcode = format("E%03d", intcode)
  message = lbt.err.messages[strcode]
  if message == nil then
    lbt.err.quit_with_error("No such error code: ", strcode)
  end
end

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
