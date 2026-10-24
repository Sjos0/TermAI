local manager = require("session.manager")

return {
  init            = manager.init,
  current         = manager.current,
  load_history    = manager.load_history,
  save_message    = manager.save_message,
  save_compaction = manager.save_compaction,
  set_model       = manager.set_model,
  new             = manager.new,
  reset           = manager.reset,
  list            = manager.list,
  switch          = manager.switch,
  status          = manager.status,
  cleanup         = manager.cleanup,
  get_flush_index = manager.get_flush_index,
  save_flush_index= manager.save_flush_index,
  save_session_tokens = manager.save_session_tokens,
  load_session_tokens = manager.load_session_tokens,
  delete_current      = manager.delete_current,
}
