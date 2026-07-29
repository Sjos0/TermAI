## 2026-05-30 - [Command Injection via Endpoint and API Key Interpolation]
**Vulnerability:** User-defined model endpoints and API keys were interpolated directly into `curl` commands and executed via `io.popen` in `models/validate.lua` and search providers. This allowed shell command execution if they contained characters like semicolons, backticks, or subshell expansions.
**Learning:** Initial validation only ran on application startup and exited using `os.exit(1)`, leaving connection-testing and search endpoints unvalidated at runtime.
**Prevention:** Isolate the character validation logic into a domain module `agent/security/validator.lua` under a facade `agent/security.lua`, and expose a non-destructive `is_safe` function. Always call `is_safe` before shell-interpolating user configurations in connection tests or search providers.

## 2026-07-28 - [Command Injection via Web Fetch URL Interpolation]
**Vulnerability:** Input URLs passed to the `web_fetch` tool were directly interpolated into double-quoted shell commands (`lynx -dump` and `curl`) and executed via `io.popen`. This allowed remote or local command injection if the URL contained characters like double-quotes, dollar signs, backticks, backslashes, or control characters.
**Learning:** Checking for protocol validity (`https?://`) and SSRF indicators does not guarantee command safety when interpolating variables into shell invocation strings.
**Prevention:** Implement strict character validation in web-fetching domain modules to reject any input containing characters capable of escaping shell double-quote context (`"`, `$`, `` ` ``, `\`, `\n`, `\r`).
