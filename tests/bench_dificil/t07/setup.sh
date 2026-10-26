#!/bin/sh
d="$1"
cat > "$d/deps.txt" << 'EOF'
app: lib-a lib-b
lib-a: core
lib-b: core lib-c
lib-c: core
core:
EOF
