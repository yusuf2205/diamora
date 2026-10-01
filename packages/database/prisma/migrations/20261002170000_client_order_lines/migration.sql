-- Several colours (each with its own metres) in one customer order.
ALTER TABLE "client_orders" ADD COLUMN "lines" JSONB;
