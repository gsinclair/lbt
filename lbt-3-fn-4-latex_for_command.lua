-- A LatexForCommand exists to turn a Command into Latex. That is a complex
-- job, so it gets its own class and file so that it can be well supported by
-- private functions.

local F = string.format

local LatexForCommand = {}
LatexForCommand.mt = { __index = LatexForCommand }
local impl = {}
local err = {}

function LatexForCommand.new(parsed_command, register_expander)
  local o = {
    opcode            = parsed_command[1],
    parsed_command    = parsed_command,
    register_expander = register_expander
  }
  setmetatable(o, LatexForCommand.mt)
  return o
end

lbt.fn.LatexForCommand = LatexForCommand

-- Return:  (todo: check this!)
--   { status = 'ok', latex = [[\paragraph{Cats} Domestic creatures...]] }
--   { status = 'error', errormsg = [[ ... ]] }
--   { status = 'ctrl', ... }
function LatexForCommand:latex()
  local ok, result, ctx, cmd, opcode
  opcode = self.opcode

  -- (1) Obtain ExpansionContext object and create Command object
  ctx = lbt.fn.get_current_expansion_context()
  cmd = lbt.fn.Command.new(self.parsed_command, ctx)

  -- (2) Check that the opcode is resolved and arguments are valid.
  ;   if cmd == nil then return err.command_does_not_exist(opcode) end
  local errmsg = cmd:error_in_arguments()
  ;   if errmsg then return err.command_arguments_invalid(errmsg) end

  -- (3) Increase the command count so register lifetimes can be tracked.
  impl.inc_command_count()

  -- (4) Expand register references in posargs and kwargs.
  local posargs, kwargs = impl.expand_register_references(cmd, self.register_expander)
  cmd:update_posargs(posargs); cmd:update_kwargs(kwargs)

  -- (5) Apply the command function, get the result, return 'error' if necessary.
  ;         -- XXX: I want opargs to be resolved at this stage, so that 'nopar = true' becomes 'par = false'.
  ;         --      But this is a challenge.
  ;         -- NOTE: Actually, I think it can happen inside set_opcode_and_options().
  result = cmd:apply_function()
  ok, result = impl.classify_result(result, opcode)
  ;   if not ok then return 'error', result end

  -- (6) Do some light processing of the result: apply options (no)par and pre-/post-space.
  result = impl.post_process(result, cmd)

  -- (7) Done! Log the result and return.
  ;   impl.log_successful_result(result)
  return 'ok', result
end

-- {{{ error conditions -------------------------------------------------------

function err.command_does_not_exist(opcode)
  lbt.log('emit', '    --> NOTFOUND')
  lbt.log(2, 'opcode not resolved: %s', opcode)
  return 'notfound'
end

function err.command_arguments_invalid(errmsg)
  lbt.log('emit', '    --> ERROR: %s', errmsg)
  lbt.log(1, 'Error attempting to expand opcode:\n    %s', errmsg)
  return 'error', errmsg
end

-- }}}

-- {{{ implementation functions ------------------------------------------------

function impl.inc_command_count()
  local command_count = lbt.var.command_count
  if command_count == nil then
    lbt.err.E001_internal_logic_error('current command_count not set')
  end
  lbt.var.command_count = command_count + 1
end

function impl.expand_register_references(cmd, expander_function)
  local posargs = cmd:posargs(); local kwargs = cmd:kwargs()
  -- The `false` in the following lines is because we are not necessarily in math mode.
  posargs = posargs:map(expander_function, false)
  for k, v in kwargs:iter() do
    v = expander_function(v, false)
    kwargs[k] = v
  end
  return posargs, kwargs
end

-- return true, result      if result is good
-- return false, errormsg   if result is bad
--
-- A good result is always packaged in a pl.List.
function impl.classify_result(result, opcode)
  if type(result) == 'string' then
    return true, pl.List({result})
  elseif type(result) == 'table' and type(result.error) == 'string' then
    ;   lbt.log('emit', '    --> ERROR: %s', result.error)
    ;   lbt.log(1, 'Error occurred while processing opcode %s\n    %s', opcode, result.error)
    return false, result.error
  elseif type(result) == 'table' then
    return true, pl.List(result)
  else
    lbt.err.E325_invalid_return_from_template_function(opcode, result)
  end
end

function impl.post_process(result, cmd)
  local extras = cmd:oparg_values { 'par', 'prespace', 'postspace' }
  if extras.par then
    result:append('\\par') -- TODO: replace with general_formatting_wrap ?
  end
  if extras.prespace then
    result:insert(1, F([[\vspace{%s}]], extras.prespace))
  end
  if extras.postspace then
    result:append(F([[\vspace{%s}]], extras.postspace))
  end
  return result
end

function impl.log_successful_result(result)
  lbt.log('emit', '    --> SUCCESS')
  for line in result:iter() do
    lbt.log('emit', '       |  ' .. line)
  end
end

-- }}}

