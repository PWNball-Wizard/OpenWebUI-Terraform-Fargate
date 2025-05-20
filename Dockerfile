# Etapa 1: Build del frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . ./
ENV NODE_OPTIONS=--max-old-space-size=4096
RUN npm run build


# Etapa 2: Build del backend
FROM python:3.11-slim-bookworm AS backend-builder

# Crea usuario no root
ARG UID=1000
ARG GID=1000
ARG APP_USER=webui
ENV HOME=/home/$APP_USER

RUN groupadd --gid ${GID} ${APP_USER} && \
    useradd --uid ${UID} --gid ${GID} --home-dir ${HOME} --create-home --shell /usr/sbin/nologin ${APP_USER}

# Instala dependencias necesarias y limpia
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ffmpeg libsndfile1 ca-certificates jq && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copia requerimientos e instala dependencias
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# Etapa final: imagen endurecida
FROM python:3.11-slim-bookworm AS final

# Reutiliza usuario sin privilegios
ARG UID=1000
ARG GID=1000
ARG APP_USER=webui
ENV HOME=/home/$APP_USER
ENV PORT=8080

LABEL org.opencontainers.image.title="Open WebUI" \
      org.opencontainers.image.description="Endurecida, multistage, sin root." \
      maintainer="tucorreo@ejemplo.com"

# Instala solo runtime necesario
RUN groupadd --gid ${GID} ${APP_USER} && \
    useradd --uid ${UID} --gid ${GID} --home-dir ${HOME} --create-home --shell /usr/sbin/nologin ${APP_USER} && \
    apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg libsndfile1 curl jq && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Directorio de trabajo
WORKDIR /app

# Copiar desde build stages
COPY --from=frontend-builder /app/build ./build
COPY --from=backend-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend-builder /usr/local/bin /usr/local/bin
COPY backend /app/backend

# Ajustar permisos
RUN chown -R ${UID}:${GID} /app

# Usar usuario no root
USER ${UID}:${GID}

# Variables de entorno necesarias
ENV WHISPER_MODEL_DIR="/app/backend/data/cache/whisper/models" \
    SENTENCE_TRANSFORMERS_HOME="/app/backend/data/cache/embedding/models" \
    TIKTOKEN_CACHE_DIR="/app/backend/data/cache/tiktoken" \
    TORCH_EXTENSIONS_DIR="/home/${APP_USER}/.cache/torch_extensions" \
    HF_HOME="/app/backend/data/cache/embedding/models"

# Exponer puerto
EXPOSE ${PORT}

# Healthcheck
HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT}/health | jq -e '.status == "true"' || exit 1

# Entrypoint (reemplaza start.sh)
CMD ["python3", "-m", "app.main"]
