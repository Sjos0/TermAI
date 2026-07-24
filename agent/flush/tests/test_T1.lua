-- Test T1: FlushState — Tabela de estado do protocolo (TDD isolado)
-- Testa o CONCEITO da tabela flush_state antes de implementar.
-- NÃO carrega agent.flush (depende de API real).

-- 1. Definição do FlushState (será INSERIDA em flush.lua)
local flush_state = {
  exec = false,
  read = false,
  edit = false,
  done = false,
}

function flush_state.reset()
  flush_state.exec = false
  flush_state.read = false
  flush_state.edit = false
  flush_state.done = false
end

-- 2. Testes do estado

-- Teste 1: Estado inicial
assert(flush_state.exec == false, "exec deveria ser false inicialmente")
assert(flush_state.read == false, "read deveria ser false inicialmente")
assert(flush_state.edit == false, "edit deveria ser false inicialmente")
assert(flush_state.done == false, "done deveria ser false inicialmente")
print("✅ Teste 1: Estado inicial (4 campos false)")

-- Teste 2: Marcação individual
flush_state.exec = true
assert(flush_state.exec == true, "exec=true falhou")
assert(flush_state.read == false, "marcar exec NÃO deve afetar read")
flush_state.read = true
assert(flush_state.read == true, "read=true falhou")
assert(flush_state.edit == false, "marcar read NÃO deve afetar edit")
flush_state.edit = true
assert(flush_state.edit == true, "edit=true falhou")
flush_state.done = true
assert(flush_state.done == true, "done=true falhou")
print("✅ Teste 2: Marcação individual funciona (sem contaminação entre campos)")

-- Teste 3: Reset
flush_state.reset()
assert(flush_state.exec == false, "reset: exec deveria voltar a false")
assert(flush_state.read == false, "reset: read deveria voltar a false")
assert(flush_state.edit == false, "reset: edit deveria voltar a false")
assert(flush_state.done == false, "reset: done deveria voltar a false")
print("✅ Teste 3: Reset funciona (4 campos voltam a false)")

-- Teste 4: Todos simultâneos
flush_state.exec = true
flush_state.read = true
flush_state.edit = true
flush_state.done = true
assert(flush_state.exec == true, "todos: exec")
assert(flush_state.read == true, "todos: read")
assert(flush_state.edit == true, "todos: edit")
assert(flush_state.done == true, "todos: done")
print("✅ Teste 4: Marcação simultânea funciona")

-- Teste 5: Reset pós-tudo-marcado
flush_state.reset()
assert(flush_state.exec == false and flush_state.done == false, "reset pós-total falhou")
print("✅ Teste 5: Reset pós-marcação total funciona")

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ T1: FlushState — TODOS OS 5 TESTES PASSARAM")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

-- 3. Validação da implementação (será usada após modificar flush.lua)
print("---")
print("⚠️  ATENÇÃO: Teste isolado do CONCEITO passou!")
print("   Para validar a implementação REAL em flush.lua,")
print("   execute: lua agente/flush/tests/validate_T1.lua")
print("---")

os.exit(0)
