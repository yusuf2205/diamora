# Backup runner: PostgreSQL client tools, mc (MinIO mirror), age (optional .env encryption), busybox crond. Everything stays on the NAS.
ARG MC_IMAGE=quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z
FROM ${MC_IMAGE} AS mc

FROM alpine:3.22
RUN apk add --no-cache postgresql17-client tzdata age tar gzip coreutils findutils bash
COPY --from=mc /usr/bin/mc /usr/local/bin/mc
COPY infra/backup/ /opt/backup/
RUN chmod +x /opt/backup/*.sh
ENTRYPOINT ["/opt/backup/entrypoint.sh"]
