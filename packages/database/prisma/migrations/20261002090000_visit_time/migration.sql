-- «Удобное время»: when a worker is happy for staff to come (deliver materials / collect work).
ALTER TABLE "worker_profiles" ADD COLUMN "visitTime" JSONB;
