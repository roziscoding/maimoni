CREATE TABLE "conversions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"month_id" uuid NOT NULL,
	"day" smallint NOT NULL,
	"sent_brl" numeric(14, 2) NOT NULL,
	"fee_brl" numeric(14, 2) NOT NULL,
	"received_eur" numeric(14, 2) NOT NULL,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "conversions_day_range" CHECK ("conversions"."day" between 1 and 31),
	CONSTRAINT "conversions_sent_positive" CHECK ("conversions"."sent_brl" > 0),
	CONSTRAINT "conversions_fee_range" CHECK ("conversions"."fee_brl" >= 0 and "conversions"."fee_brl" <= "conversions"."sent_brl"),
	CONSTRAINT "conversions_received_positive" CHECK ("conversions"."received_eur" > 0)
);
--> statement-breakpoint
ALTER TABLE "conversions" ADD CONSTRAINT "conversions_month_id_months_id_fk" FOREIGN KEY ("month_id") REFERENCES "public"."months"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "conversions_month_id_day" ON "conversions" USING btree ("month_id","day");--> statement-breakpoint
ALTER TABLE "months" DROP COLUMN "received_eur";