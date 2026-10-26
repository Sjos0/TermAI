#!/bin/sh
d="$1"
cat > "$d/auth.log" << 'EOF'
2026-10-01 10:00 FAIL user=ana ip=10.0.0.5
2026-10-01 10:01 OK user=ana ip=10.0.0.5
2026-10-01 10:02 FAIL user=bia ip=10.0.0.7
2026-10-01 10:03 FAIL user=caio ip=192.168.1.9
2026-10-01 10:04 FAIL user=bia ip=10.0.0.7
2026-10-01 10:05 FAIL user=dani ip=10.0.0.7
2026-10-01 10:06 FAIL user=ana ip=10.0.0.5
2026-10-01 10:07 FAIL user=eli ip=10.0.0.7
2026-10-01 10:08 FAIL user=caio ip=192.168.1.9
2026-10-01 10:09 OK user=bia ip=10.0.0.7
2026-10-01 10:10 FAIL user=fe ip=192.168.1.9
EOF
