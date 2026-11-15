ALTER TABLE "conversions" DROP CONSTRAINT "conversions_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "daily_spends" DROP CONSTRAINT "daily_spends_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "month_items" DROP CONSTRAINT "month_items_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "months" DROP CONSTRAINT "months_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "settings" DROP CONSTRAINT "settings_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "template_items" DROP CONSTRAINT "template_items_user_id_user_id_fk";
--> statement-breakpoint
ALTER TABLE "conversions" ADD CONSTRAINT "conversions_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "daily_spends" ADD CONSTRAINT "daily_spends_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "month_items" ADD CONSTRAINT "month_items_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "months" ADD CONSTRAINT "months_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "settings" ADD CONSTRAINT "settings_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "template_items" ADD CONSTRAINT "template_items_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE cascade;