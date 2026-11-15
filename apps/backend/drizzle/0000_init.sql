CREATE TYPE "public"."currency" AS ENUM('BRL', 'EUR');--> statement-breakpoint
CREATE TYPE "public"."entry_kind" AS ENUM('income', 'expense');--> statement-breakpoint
CREATE TABLE "exchange_rates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"base" "currency" NOT NULL,
	"quote" "currency" NOT NULL,
	"rate" numeric(12, 6) NOT NULL,
	"source" text NOT NULL,
	"fetched_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "month_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"month_id" uuid NOT NULL,
	"template_item_id" uuid,
	"name" text NOT NULL,
	"currency" "currency" NOT NULL,
	"kind" "entry_kind" DEFAULT 'expense' NOT NULL,
	"amount" numeric(14, 2),
	"expression" text,
	"paid" boolean DEFAULT false NOT NULL,
	"needs_review" boolean DEFAULT false NOT NULL,
	"position" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "months" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"year" smallint NOT NULL,
	"month" smallint NOT NULL,
	"wise_fee" numeric(6, 5) NOT NULL,
	"exchange_rate" numeric(12, 6),
	"received_eur" numeric(14, 2),
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "months_year_month" UNIQUE("year","month"),
	CONSTRAINT "months_month_range" CHECK ("months"."month" between 1 and 12)
);
--> statement-breakpoint
CREATE TABLE "settings" (
	"id" smallint PRIMARY KEY DEFAULT 1 NOT NULL,
	"wise_fee" numeric(6, 5) DEFAULT 0.039 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "settings_singleton" CHECK ("settings"."id" = 1)
);
--> statement-breakpoint
CREATE TABLE "template_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"currency" "currency" NOT NULL,
	"kind" "entry_kind" DEFAULT 'expense' NOT NULL,
	"amount" numeric(14, 2),
	"expression" text,
	"variable" boolean DEFAULT false NOT NULL,
	"position" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "month_items" ADD CONSTRAINT "month_items_month_id_months_id_fk" FOREIGN KEY ("month_id") REFERENCES "public"."months"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "month_items" ADD CONSTRAINT "month_items_template_item_id_template_items_id_fk" FOREIGN KEY ("template_item_id") REFERENCES "public"."template_items"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "exchange_rates_pair_fetched_at" ON "exchange_rates" USING btree ("base","quote","fetched_at");--> statement-breakpoint
CREATE INDEX "month_items_month_id" ON "month_items" USING btree ("month_id");