#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"
MODEL="${HERMES_MODEL:-deepseek/deepseek-chat}"
PROVIDER="${HERMES_PROVIDER:-openrouter}"

echo "[boot] HERMES_HOME=$HERMES_HOME"
echo "[boot] MODEL=$MODEL via $PROVIDER"

# Garantir diretorios
mkdir -p "$HERMES_HOME"

# Bootstrap config.yaml se nao existir
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    echo "[boot] Criando config.yaml padrao..."
    cat > "$HERMES_HOME/config.yaml" << 'YAML'
model:
  default: deepseek/deepseek-chat
  provider: openrouter
  base_url: https://openrouter.ai/api/v1
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

# Sobrescrever model/provider via env vars (pro gateway)
python3 -c "
import yaml, os
path = '$HERMES_HOME/config.yaml'
with open(path) as f:
    cfg = yaml.safe_load(f)
changed = False
model_var = os.environ.get('HERMES_MODEL')
prov_var = os.environ.get('HERMES_PROVIDER')
if model_var:
    cfg.setdefault('model', {})['default'] = model_var
    changed = True
if prov_var:
    cfg.setdefault('model', {})['provider'] = prov_var
    changed = True
if changed:
    with open(path, 'w') as f:
        yaml.dump(cfg, f, default_flow_style=False)
    print(f'[boot] Modelo atualizado: {model_var} via {prov_var}')
" 2>&1 | tail -1

# Escrever .env se tiver variaveis
if [ -n "$OPENROUTER_API_KEY" ]; then
    echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" > "$HERMES_HOME/.env"
    echo "[boot] .env criado com OPENROUTER_API_KEY"
elif [ -n "$DEEPSEEK_API_KEY" ]; then
    echo "DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY" > "$HERMES_HOME/.env"
    echo "[boot] .env criado com DEEPSEEK_API_KEY"
fi

# Garantir permissoes
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
