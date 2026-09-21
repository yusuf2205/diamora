#!/bin/sh
# One-shot, idempotent MinIO provisioning: buckets, hard per-bucket quotas, least-privilege identities (`app` rw, `backup` ro).
set -eu
ALIAS=local
PREFIX="${S3_BUCKET_PREFIX:-}"
BUCKETS="collateral assignments products quality documents avatars"
VERSIONED="collateral documents quality"

mc alias set "$ALIAS" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
for b in $BUCKETS; do
  mc mb --ignore-existing "$ALIAS/${PREFIX}${b}"
  mc anonymous set none "$ALIAS/${PREFIX}${b}" >/dev/null           # never public: files are served by the API via signed URLs
  if [ "${MINIO_BUCKET_QUOTA_GB:-0}" -gt 0 ] 2>/dev/null; then
    mc quota set "$ALIAS/${PREFIX}${b}" --size "${MINIO_BUCKET_QUOTA_GB}GiB" >/dev/null 2>&1 || echo "warn: quota not set on ${PREFIX}${b}"
  fi
done
for b in $VERSIONED; do mc version enable "$ALIAS/${PREFIX}${b}" >/dev/null 2>&1 || true; done

res=""
for b in $BUCKETS; do res="${res}\"arn:aws:s3:::${PREFIX}${b}\",\"arn:aws:s3:::${PREFIX}${b}/*\","; done
res="${res%,}"
cat > /tmp/app-rw.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:ListBucket","s3:GetBucketLocation"],"Resource":[${res}]}]}
JSON
cat > /tmp/backup-ro.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket","s3:GetBucketLocation"],"Resource":[${res}]}]}
JSON
mc admin policy create "$ALIAS" app-rw /tmp/app-rw.json >/dev/null 2>&1 || true
mc admin policy create "$ALIAS" backup-ro /tmp/backup-ro.json >/dev/null 2>&1 || true
mc admin user add "$ALIAS" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" >/dev/null
mc admin policy attach "$ALIAS" app-rw --user "$S3_ACCESS_KEY" >/dev/null 2>&1 || true
mc admin user add "$ALIAS" "$S3_BACKUP_ACCESS_KEY" "$S3_BACKUP_SECRET_KEY" >/dev/null
mc admin policy attach "$ALIAS" backup-ro --user "$S3_BACKUP_ACCESS_KEY" >/dev/null 2>&1 || true
echo "minio-init: buckets, quotas and identities are ready"
