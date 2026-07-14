#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

echo "[boot] HERMES_HOME=$HERMES_HOME"
echo "[boot] MODEL=${HERMES_MODEL:-big-pickle}"
echo "[boot] PROVIDER=${HERMES_PROVIDER:-opencode-zen}"

mkdir -p "$HERMES_HOME"

# Criar config.yaml com valores diretos (sem Python)
cat > "$HERMES_HOME/config.yaml" << YAML
model:
  default: ${HERMES_MODEL:-big-pickle}
  provider: ${HERMES_PROVIDER:-opencode-zen}
  base_url: ${HERMES_BASE_URL:-https://opencode.ai/zen/v1}
  context_length: 128000
agent:
  max_turns: 50
  tool_use_enforcement: false
display:
  skin: default
  show_cost: false
security:
  tirith_enabled: false
  redact_secrets: false
YAML

# Escrever .env com a chave certa
if [ -n "$OPENCODE_ZEN_API_KEY" ]; then
    echo "OPENCODE_ZEN_API_KEY=$OPENCODE_ZEN_API_KEY" > "$HERMES_HOME/.env"
    echo "[boot] Usando OpenCode Zen"
elif [ -n "$OPENROUTER_API_KEY" ]; then
    echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" > "$HERMES_HOME/.env"
    echo "[boot] Usando OpenRouter"
fi

chmod 600 "$HERMES_HOME/.env" 2>/dev/null || true

echo "[boot] Iniciando servidor web..."
exec gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 1 \
    --threads 4 \
    --timeout 180 \
    --access-logfile - \
    --error-logfile - \
    app:app
