ALTER TYPE "public"."currency" ADD VALUE 'AUD' BEFORE 'BRL';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'CAD' BEFORE 'EUR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'CHF' BEFORE 'EUR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'CNY' BEFORE 'EUR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'CZK' BEFORE 'EUR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'DKK' BEFORE 'EUR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'GBP';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'HKD';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'HUF';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'IDR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'ILS';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'INR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'ISK';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'JPY';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'KRW';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'MXN';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'MYR';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'NOK';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'NZD';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'PHP';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'PLN';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'RON';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'SEK';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'SGD';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'THB';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'TRY';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'USD';--> statement-breakpoint
ALTER TYPE "public"."currency" ADD VALUE 'ZAR';--> statement-breakpoint
ALTER TABLE "exchange_rates" ALTER COLUMN "rate" SET DATA TYPE numeric(20, 10);