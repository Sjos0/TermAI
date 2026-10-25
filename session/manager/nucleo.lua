-- session/manager/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local generate   = require("session.generate")
  local store      = require("session.store")
  local state      = require("session.manager.state")
  local date_utils = require("session.manager.date_utils")
  local reset_pol  = require("session.manager.reset_policy")
  local sess_ops   = require("session.manager.session_ops")
  local hist       = require("session.manager.history")
  local msgs       = require("session.manager.messages")
  local flush      = require("session.manager.flush_index")
  local cleanup    = require("session.manager.cleanup")
  local orphan     = require("session.manager.orphan_scan")

  local N = {}
  N.generate = generate
  N.store = store
  N.state = state
  N.date_utils = date_utils
  N.reset_pol = reset_pol
  N.sess_ops = sess_ops
  N.hist = hist
  N.msgs = msgs
  N.flush = flush
  N.cleanup = cleanup
  N.orphan = orphan
  return N
end
