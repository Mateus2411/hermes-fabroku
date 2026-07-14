# Hermes Fabroku

Deploy do **Hermes Agent** com **DeepSeek** no Fabroku (IFC).

## Stack

- **Hermes Agent** — CLI de IA autônoma (Nous Research)
- **DeepSeek** — modelo via OpenRouter
- **Flask + Gunicorn** — web chat
- **Docker** — containerizado

## Como usar

1. Faça deploy no Fabroku apontando pra este repo
2. Configure a env var `OPENROUTER_API_KEY`
3. Acesse o app no domínio `*.class.fabricadesoftware.ifc.edu.br`

## Variáveis de Ambiente

| Variável | Obrigatório | Descrição |
|----------|-------------|-----------|
| `OPENROUTER_API_KEY` | ✅ | Chave da OpenRouter (com acesso a DeepSeek) |
| `HERMES_MODEL` | ❌ | Modelo (padrão: `deepseek/deepseek-chat`) |
| `HERMES_PROVIDER` | ❌ | Provider (padrão: `openrouter`) |
| `DEEPSEEK_API_KEY` | ❌ | Alternativa: chave direta da DeepSeek |

## Estrutura

```
├── Dockerfile        # Build do container
├── start.sh          # Entrypoint
├── app.py            # Flask web chat
├── templates/
│   └── index.html    # Chat UI
├── config.yaml       # Config Hermes (DeepSeek)
└── requirements.txt  # Dependências Python
```
