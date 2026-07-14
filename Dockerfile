FROM python:3.11-slim-bookworm

LABEL description="Hermes Agent - Web Chat com DeepSeek"
LABEL maintainer="Mateus2411"

# System deps (mínimo)
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Instalar uv e hermes-agent
RUN pip install --no-cache-dir uv
ENV UV_TOOL_DIR=/opt/hermes-tools \
    PATH="/opt/hermes-tools/bin:${PATH}"
RUN uv tool install hermes-agent

# Instalar dependencias web
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# App
WORKDIR /app
COPY . .
RUN chmod +x /app/start.sh

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

ENTRYPOINT ["/app/start.sh"]
