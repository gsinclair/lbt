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
  message = format(msg, ...)
  traceback = debug.traceback()
  message = "\n\n\n" + message + "\n\n\n" + debug.traceback() + "\n\n\n"
  lbt.log(message)
  lbt.dbg(message)
  print(message)
  os.exit()
end

local E = lbt.err.quit_with_error

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
