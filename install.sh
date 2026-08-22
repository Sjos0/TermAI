#!/data/data/com.termux/files/usr/bin/bash
# install.sh — instalador de um comando só do TermAI para Termux.
# Idempotente: pode rodar de novo sem duplicar nada nem sobrescrever config existente.
set -e

echo "🦇 Instalando TermAI..."

# 1. Dependências — pkg já ignora sozinho o que já está instalado, não precisa checar antes.
#    NOTA: o pacote Lua no Termux é "lua54" (fornece o binário lua5.4), não "lua5.4".
pkg install -y lua54 git curl

# 1b. Garante o diretório de dados do TermAI (hoje ninguém cria).
mkdir -p "$HOME/.TermAI"

# 2. Comando global "TermAI" — real binário no PATH, sem alias e sem tocar em .bashrc.
#    $PREFIX/bin já está no PATH por padrão em qualquer sessão do Termux.
#    Loop de restart: agent/restart.lua sai com os.exit(123) quando o próprio
#    TermAI pede reinício (ex: após mudança de código/config). Sem esse loop,
#    o processo simplesmente encerra e devolve o usuário pro shell do Termux
#    em vez de voltar pro prompt do TermAI.
WRAPPER="$PREFIX/bin/TermAI"
cat << 'ENDOFFILE' > "$WRAPPER"
#!/data/data/com.termux/files/usr/bin/bash
while true; do
  lua5.4 "$HOME/TermAI/main.lua" "$@"
  status=$?
  if [ "$status" -ne 123 ]; then
    exit "$status"
  fi
done
ENDOFFILE
chmod +x "$WRAPPER"

echo ""
echo "✅ TermAI instalado! De qualquer pasta, use:"
echo ""
echo "   TermAI models add-provider   → configura seu provedor de IA (primeiro passo)"
echo "   TermAI tui                   → inicia o agente"
echo ""
