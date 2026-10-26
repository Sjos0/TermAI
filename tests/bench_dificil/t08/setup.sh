#!/bin/sh
d="$1"
cat > "$d/registros.csv" << 'EOF'
id,nome,atualizado
7,Ana,2026-10-01 10:00
3,Bruno,2026-09-28 08:00
7,Ana Paula,2026-10-02 09:00
5,Carla,01/10/2026 12:00
3,Bruno,2026-09-30 08:00
EOF
