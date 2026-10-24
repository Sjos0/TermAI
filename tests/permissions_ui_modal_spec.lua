package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/permissions_ui_modal_spec.lua — Lifecycle alternate screen (PR #24 v5)

package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.permissions_ui_modal_spec.01_1_lifecycle_alternate_scre",
  "tests.permissions_ui_modal_spec.02_3_cleanup_em_erro_xpcall",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("PERMISSIONS UI MODAL: %d passaram, %d falharam", harness.pass, harness.fail))
print(string.rep("═", 60))
if harness.fail > 0 then os.exit(1) end

