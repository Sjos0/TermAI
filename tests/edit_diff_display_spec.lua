-- tests/edit_diff_display_spec.lua — Investigação do bug: Edit não mostra diff na TUI
-- Testa diff_builder e edit_renderer isoladamente para isolar a causa raiz.


package.path = "./?.lua;./?/init.lua;./tools/?.lua;./tools/editor/?.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.edit_diff_display_spec.01_parte",
  "tests.edit_diff_display_spec.02_2_result_builder_build",
  "tests.edit_diff_display_spec.03_3_edit_renderer_render_edi",
  "tests.edit_diff_display_spec.04_4_pipeline_completo_simula",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("EDIT DIFF DISPLAY: %d passaram, %d falharam", harness.pass, harness.fail))
print(string.rep("═", 60))
if harness.fail > 0 then os.exit(1) end

