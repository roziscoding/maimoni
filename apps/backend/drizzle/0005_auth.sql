CREATE TABLE "account" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"account_id" text NOT NULL,
	"provider_id" text NOT NULL,
	"access_token" text,
	"refresh_token" text,
	"id_token" text,
	"access_token_expires_at" timestamp with time zone,
	"refresh_token_expires_at" timestamp with time zone,
	"scope" text,
	"password" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "passkey" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text,
	"public_key" text NOT NULL,
	"credential_id" text NOT NULL,
	"counter" integer NOT NULL,
	"device_type" text NOT NULL,
	"backed_up" boolean NOT NULL,
	"transports" text,
	"aaguid" text,
	"created_at" timestamp with time zone DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "session" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"ip_address" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "session_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "user" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"email_verified" boolean DEFAULT false NOT NULL,
	"image" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "verification" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
-- Existing data predates users: when there is any, it goes to a placeholder owner, which becomes a
-- real account by updating its email and setting email_verified (see docs/decisions.md).
INSERT INTO "user" ("id", "name", "email") SELECT '00000000-0000-4000-8000-000000000001', 'Owner', 'owner@maimoni.invalid'
WHERE EXISTS (SELECT 1 FROM "months") OR EXISTS (SELECT 1 FROM "template_items") OR EXISTS (SELECT 1 FROM "settings");--> statement-breakpoint
ALTER TABLE "months" DROP CONSTRAINT "months_year_month";--> statement-breakpoint
ALTER TABLE "settings" DROP CONSTRAINT "settings_singleton";--> statement-breakpoint
ALTER TABLE "months" ADD COLUMN "user_id" uuid;--> statement-breakpoint
ALTER TABLE "settings" ADD COLUMN "user_id" uuid;--> statement-breakpoint
ALTER TABLE "template_items" ADD COLUMN "user_id" uuid;--> statement-breakpoint
UPDATE "months" SET "user_id" = '00000000-0000-4000-8000-000000000001';--> statement-breakpoint
UPDATE "settings" SET "user_id" = '00000000-0000-4000-8000-000000000001';--> statement-breakpoint
UPDATE "template_items" SET "user_id" = '00000000-0000-4000-8000-000000000001';--> statement-breakpoint
ALTER TABLE "months" ALTER COLUMN "user_id" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "template_items" ALTER COLUMN "user_id" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "settings" DROP COLUMN "id";--> statement-breakpoint
ALTER TABLE "settings" ADD PRIMARY KEY ("user_id");--> statement-breakpoint
ALTER TABLE "account" ADD CONSTRAINT "account_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "passkey" ADD CONSTRAINT "passkey_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "account_user_id" ON "account" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "passkey_user_id" ON "passkey" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "passkey_credential_id" ON "passkey" USING btree ("credential_id");--> statement-breakpoint
CREATE INDEX "session_user_id" ON "session" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "verification_identifier" ON "verification" USING btree ("identifier");--> statement-breakpoint
ALTER TABLE "months" ADD CONSTRAINT "months_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settings" ADD CONSTRAINT "settings_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "template_items" ADD CONSTRAINT "template_items_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "template_items_user_id" ON "template_items" USING btree ("user_id");--> statement-breakpoint
ALTER TABLE "months" ADD CONSTRAINT "months_user_id_year_month" UNIQUE("user_id","year","month");--> statement-breakpoint
ALTER TABLE "months" ADD CONSTRAINT "months_id_user_id" UNIQUE("id","user_id");
--> statement-breakpoint
ALTER TABLE "conversions" DROP CONSTRAINT "conversions_month_id_months_id_fk";
--> statement-breakpoint
ALTER TABLE "daily_spends" DROP CONSTRAINT "daily_spends_month_id_months_id_fk";
--> statement-breakpoint
ALTER TABLE "month_items" DROP CONSTRAINT "month_items_month_id_months_id_fk";
--> statement-breakpoint
ALTER TABLE "conversions" ADD COLUMN "user_id" uuid;
--> statement-breakpoint
ALTER TABLE "daily_spends" ADD COLUMN "user_id" uuid;
--> statement-breakpoint
ALTER TABLE "month_items" ADD COLUMN "user_id" uuid;
--> statement-breakpoint
UPDATE "conversions" SET "user_id" = "months"."user_id" FROM "months" WHERE "conversions"."month_id" = "months"."id";
--> statement-breakpoint
UPDATE "daily_spends" SET "user_id" = "months"."user_id" FROM "months" WHERE "daily_spends"."month_id" = "months"."id";
--> statement-breakpoint
UPDATE "month_items" SET "user_id" = "months"."user_id" FROM "months" WHERE "month_items"."month_id" = "months"."id";
--> statement-breakpoint
ALTER TABLE "conversions" ALTER COLUMN "user_id" SET NOT NULL;
--> statement-breakpoint
ALTER TABLE "daily_spends" ALTER COLUMN "user_id" SET NOT NULL;
--> statement-breakpoint
ALTER TABLE "month_items" ALTER COLUMN "user_id" SET NOT NULL;
--> statement-breakpoint
ALTER TABLE "conversions" ADD CONSTRAINT "conversions_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "conversions" ADD CONSTRAINT "conversions_month" FOREIGN KEY ("month_id","user_id") REFERENCES "public"."months"("id","user_id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "daily_spends" ADD CONSTRAINT "daily_spends_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "daily_spends" ADD CONSTRAINT "daily_spends_month" FOREIGN KEY ("month_id","user_id") REFERENCES "public"."months"("id","user_id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "month_items" ADD CONSTRAINT "month_items_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "month_items" ADD CONSTRAINT "month_items_month" FOREIGN KEY ("month_id","user_id") REFERENCES "public"."months"("id","user_id") ON DELETE cascade ON UPDATE no action;