-- Rebrand Yusmus -> Diamoraa: the one-transaction erase flag is now `diamoraa.worker_purge` (same narrow exception as
-- 20260928160000_worker_invite_delete: only the declared-collateral trail of a worker being erased, nothing else).
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' AND TG_TABLE_NAME IN ('collateral_history', 'collateral_photos')
     AND current_setting('diamoraa.worker_purge', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'table "%" is append-only: % is not allowed (use a compensating record)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;
