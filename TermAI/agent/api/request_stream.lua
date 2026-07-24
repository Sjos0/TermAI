-- agent/api/request_stream.lua — Request streaming com native tool calling (Padrão Fachada).
local M = {}
local streamer = require("agent.api.request_stream.streamer")
M.pensar_stream = streamer.pensar_stream
return M
