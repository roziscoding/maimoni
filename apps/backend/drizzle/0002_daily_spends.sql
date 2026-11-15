CREATE TABLE "daily_spends" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"month_id" uuid NOT NULL,
	"day" smallint NOT NULL,
	"amount" numeric(14, 2) NOT NULL,
	"expression" text,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "daily_spends_day_range" CHECK ("daily_spends"."day" between 1 and 31)
);
--> statement-breakpoint
ALTER TABLE "months" ADD COLUMN "active_day" smallint;--> statement-breakpoint
ALTER TABLE "daily_spends" ADD CONSTRAINT "daily_spends_month_id_months_id_fk" FOREIGN KEY ("month_id") REFERENCES "public"."months"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "daily_spends_month_id_day" ON "daily_spends" USING btree ("month_id","day");--> statement-breakpoint
ALTER TABLE "months" ADD CONSTRAINT "months_active_day_range" CHECK ("months"."active_day" between 1 and 32);