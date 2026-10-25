-- tools/exec/security/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local config_mod = require("config")
  local DESTRUCTIVE_PATTERNS = {
    { pattern = "%f[%w]rm%f[%W]%s+%-rf", message = "Comando 'rm -rf' (remoção recursiva forçada) detectado" },
    { pattern = "%f[%w]rmdir%f[%W]", message = "Comando 'rmdir' detectado" },
    { pattern = "%f[%w]mkfs%f[%W]", message = "Comando 'mkfs' (formatação de sistema de arquivos) detectado" },
    { pattern = "%f[%w]dd%f[%W]", message = "Comando 'dd' (escrita direta em disco/partição) detectado" },
    { pattern = "%f[%w]shutdown%f[%W]", message = "Comando de desligamento ('shutdown') detectado" },
    { pattern = "%f[%w]reboot%f[%W]", message = "Comando de reinicialização ('reboot') detectado" },
    { pattern = "%f[%w]shred%f[%W]", message = "Comando 'shred' (destruição de arquivos) detectado" }
  }
  local INJECTION_PATTERNS = {
    { char = ";", type = "semicolon", message = "Ponto e vírgula ';' detectado (encadeamento de comandos)" },
    { char = "|", type = "pipe", message = "Pipe '|' ou ou-lógico '||' detectado" },
    { char = "&", type = "ampersand", message = "E-comercial '&' ou e-lógico '&&' detectado" }
  }

  local N = {}
  N.config_mod = config_mod
  N.DESTRUCTIVE_PATTERNS = DESTRUCTIVE_PATTERNS
  N.INJECTION_PATTERNS = INJECTION_PATTERNS
  return N
end
