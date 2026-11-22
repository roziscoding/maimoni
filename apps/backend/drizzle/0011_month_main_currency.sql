-- Every month so far was worked out in euros, so existing rows take EUR; new ones are given the user's main currency.
ALTER TABLE "months" ADD COLUMN "main_currency" "currency" DEFAULT 'EUR' NOT NULL;--> statement-breakpoint
ALTER TABLE "months" ALTER COLUMN "main_currency" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "months" ADD COLUMN "locked_rates" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
-- The single locked rate was reais per euro.
UPDATE "months" SET "locked_rates" = jsonb_build_object('BRL', "exchange_rate") WHERE "exchange_rate" IS NOT NULL;
