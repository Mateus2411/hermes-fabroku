FROM python:3.11-slim-bookworm

LABEL description="Hermes Agent - Web Chat com DeepSeek"
LABEL maintainer="Mateus2411"

# System deps
RUN apt-get update && apt-get install -y \
    curl \
    git \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Instalar Hermes Agent
RUN curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"

# Instalar dependencias web
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Criar dir do app
WORKDIR /app
COPY . .

RUN mkdir -p /data/hermes

# Porta web
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

ENTRYPOINT ["/app/start.sh"]
