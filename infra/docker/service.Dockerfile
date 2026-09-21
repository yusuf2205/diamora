# syntax=docker/dockerfile:1.7
# One image for the API (dist/main.js), the Telegram bot worker (dist/worker.js) and the migrator (target: migrator).
#   docker build -f infra/docker/service.Dockerfile --target runtime  .
#   docker build -f infra/docker/service.Dockerfile --target migrator .
# Works on x86_64 and ARM64 NAS (Debian glibc; Prisma binary targets for both).
ARG NODE_IMAGE=node:24-bookworm-slim

FROM ${NODE_IMAGE} AS base
ENV PNPM_HOME=/pnpm PATH=/pnpm:$PATH CI=true npm_config_update_notifier=false
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/* && npm install -g pnpm@12.4.1 --no-fund --no-audit
WORKDIR /repo

FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/config/package.json packages/config/package.json
COPY packages/shared/package.json packages/shared/package.json
COPY packages/database/package.json packages/database/package.json
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store pnpm install --frozen-lockfile

FROM deps AS build
COPY packages packages
COPY apps/api apps/api
COPY infra/scripts/prisma-deployed.mjs infra/scripts/prisma-deployed.mjs
RUN pnpm --filter @yusmus/shared build && pnpm --filter @yusmus/database build && pnpm --filter @yusmus/api build \
 && pnpm --filter @yusmus/api deploy --prod /out \
 && node infra/scripts/prisma-deployed.mjs /out generate \
 && cp infra/scripts/prisma-deployed.mjs /out/prisma-deployed.mjs

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates tini && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build --chown=node:node /out /app
USER node
ENTRYPOINT ["/usr/bin/tini", "--", "node"]
CMD ["dist/main.js"]

# one-shot: applies migrations, then exits
FROM runtime AS migrator
CMD ["prisma-deployed.mjs", "/app", "migrate", "deploy"]
