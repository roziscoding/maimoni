ALTER TABLE "user" ADD COLUMN "onboarded" boolean DEFAULT false NOT NULL;--> statement-breakpoint
-- Whoever already has an account set the app up before there was a first-run setup.
UPDATE "user" SET "onboarded" = true;