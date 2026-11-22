CREATE TABLE "user_currencies" (
	"user_id" uuid NOT NULL,
	"currency" "currency" NOT NULL,
	"is_main_currency" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_currencies_pkey" PRIMARY KEY("user_id","currency")
);
--> statement-breakpoint
ALTER TABLE "user_currencies" ADD CONSTRAINT "user_currencies_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
CREATE UNIQUE INDEX "user_currencies_main" ON "user_currencies" USING btree ("user_id") WHERE "user_currencies"."is_main_currency";--> statement-breakpoint
INSERT INTO "user_currencies" ("user_id", "currency", "is_main_currency")
SELECT "user"."id", "defaults"."currency", "defaults"."is_main_currency"
FROM "user"
CROSS JOIN (VALUES ('EUR'::"currency", true), ('BRL'::"currency", false)) AS "defaults" ("currency", "is_main_currency");