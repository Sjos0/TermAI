-- TermAI cron: inspect and manually execute OS-cron jobs without a resident scheduler.
local J = require("commands.cron.jobs")

local action = arg[2]
if action == "--help" or action == "-h" or action == nil then
  io.write("Uso: TermAI cron list | run <bugs-hunter|code-review> | runs <job> [limite]\n")
  io.write("  list                Lista os jobs TermAI presentes no crontab do sistema\n")
  io.write("  run <job>           Executa agora o mesmo runner usado pelo cron\n")
  io.write("  runs <job> [limite] Lista as últimas execuções e seus códigos de saída\n")
elseif action == "list" then
  J.list_jobs()
elseif action == "run" then
  J.run_job(arg[3])
elseif action == "runs" then
  J.list_runs(arg[3], arg[4])
else
  io.stderr:write("Subcomando desconhecido: " .. tostring(action) .. "\n")
  io.stderr:write("Use: TermAI cron --help\n")
  os.exit(2)
end