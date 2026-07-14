#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

echo "[boot] HERMES_HOME=$HERMES_HOME"

mkdir -p "$HERMES_HOME"

# Criar config.yaml se nao existir
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    echo "[boot] Criando config.yaml padrao..."
    cat > "$HERMES_HOME/config.yaml" << 'YAML'
model:
  default: big-pickle
  provider: opencode-zen
  base_url: https://opencode.ai/zen/v1
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
fi

# Sobrescrever config via env vars
python3 -c "
import yaml, os
path = '$HERMES_HOME/config.yaml'
with open(path) as f:
    cfg = yaml.safe_load(f)
changed = False
for env_key, cfg_path in [
    ('HERMES_MODEL', ['model', 'default']),
    ('HERMES_PROVIDER', ['model', 'provider']),
    ('HERMES_BASE_URL', ['model', 'base_url']),
]:
    val = os.environ.get(env_key)
    if val:
        d = cfg
        for k in cfg_path[:-1]:
            d = d.setdefault(k, {})
        d[cfg_path[-1]] = val
        changed = True
if changed:
    with open(path, 'w') as f:
        yaml.dump(cfg, f, default_flow_style=False)
    print('[boot] Config atualizada via env vars')
"

# Escrever .env com a chave certa
API_KEY=""
if [ -n "$OPENCODE_ZEN_API_KEY" ]; then
    API_KEY="$OPENCODE_ZEN_API_KEY"
    echo "OPENCODE_ZEN_API_KEY=$API_KEY" > "$HERMES_HOME/.env"
    echo "[boot] Usando OpenCode Zen"
elif [ -n "$OPENROUTER_API_KEY" ]; then
    API_KEY="$OPENROUTER_API_KEY"
    echo "OPENROUTER_API_KEY=$API_KEY" > "$HERMES_HOME/.env"
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
