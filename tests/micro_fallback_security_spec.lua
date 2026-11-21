package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local utils = require("agent.api.utils")
local safe = utils.redact_endpoint("https://generativelanguage.googleapis.com/v1/models/m?key=secret-token&alt=sse")
assert(safe:find("key=%[REDACTED%]", 1) ~= nil, "query API key must be redacted")
assert(safe:find("secret%-token") == nil, "secret must not appear in diagnostics")
assert(safe:find("alt=sse", 1, true) ~= nil, "non-secret query parameters should remain")
local body = utils.redact_secret("invalid key: secret-token", "secret-token")
assert(body == "invalid key: [REDACTED]", "secret must be redacted from response details")
print("MICRO FALLBACK SECURITY: 4 assertions passed")
