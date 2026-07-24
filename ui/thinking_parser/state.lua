local M = {}

-- Maquina de estados: "content" | "thinking" | "tool"
M.mode   = "content"
M.opener = nil
M.buf    = ""

function M.reset()
  M.mode   = "content"
  M.opener = nil
  M.buf    = ""
end

function M.flush(stream_reasoning, stream_token)
  if M.buf == "" then return end
  if M.mode == "thinking" then
    stream_reasoning(M.buf)
  else
    stream_token(M.buf)
  end
  M.buf    = ""
  M.mode   = "content"
  M.opener = nil
end

return M
