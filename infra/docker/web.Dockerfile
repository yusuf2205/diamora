# syntax=docker/dockerfile:1.7
# Next.js web (standalone output). Talks to the API over the internal Docker network.
ARG NODE_IMAGE=node:24-bookworm-slim
FROM ${NODE_IMAGE} AS base
ENV PNPM_HOME=/pnpm PATH=/pnpm:$PATH CI=true npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1
RUN npm install -g pnpm@12.4.1 --no-fund --no-audit
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
ARG NEXT_PUBLIC_API_URL=https://api.example.com
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
COPY packages packages
COPY apps/web apps/web
RUN pnpm --filter @yusmus/shared build && pnpm --filter @yusmus/web build

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0
RUN apt-get update && apt-get install -y --no-install-recommends tini && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build --chown=node:node /repo/apps/web/.next/standalone ./
COPY --from=build --chown=node:node /repo/apps/web/.next/static ./apps/web/.next/static
COPY --from=build --chown=node:node /repo/apps/web/public ./apps/web/public
USER node
EXPOSE 3000
ENTRYPOINT ["/usr/bin/tini", "--", "node"]
CMD ["apps/web/server.js"]
