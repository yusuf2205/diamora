-- a worker can be looked after by a manager, an admin or the SUPER_ADMIN (owner, 2026-10-11); never by a worker
CREATE OR REPLACE FUNCTION worker_manager_must_be_manager() RETURNS trigger AS $$
BEGIN
  IF NEW."assignedManagerId" IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM users u WHERE u.id = NEW."assignedManagerId" AND u.role IN ('MANAGER', 'ADMIN', 'SUPER_ADMIN')
  ) THEN
    RAISE EXCEPTION 'worker manager must be a staff user (MANAGER, ADMIN or SUPER_ADMIN)' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
