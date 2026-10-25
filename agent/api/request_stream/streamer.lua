-- agent/api/request_stream/streamer.lua — Core loop do HTTP streaming com suporte a SSE.

local M = {}

local N = require("agent.api.request_stream.streamer.nucleo")(M)
require("agent.api.request_stream.streamer.parte_1")(M, N)

return M
