<script setup lang="ts">
/** A block of the settings page: what it is, its content, and the actions that apply to all of it. */
defineProps<{
  title: string
  description: string
  /** For what can't be undone. */
  danger?: boolean
}>()

const id = useId()
</script>

<template>
  <section :aria-labelledby="id" class="overflow-hidden rounded-xl border" :class="danger ? 'border-error/40' : 'border-default'">
    <header class="space-y-1 border-b px-4 py-3" :class="danger ? 'border-error/40' : 'border-default'">
      <h2 :id="id" class="text-base font-semibold" :class="danger ? 'text-error' : 'text-highlighted'">
        {{ title }}
      </h2>
      <p class="text-sm text-muted">
        {{ description }}
      </p>
    </header>

    <slot />

    <footer v-if="$slots.footer" class="flex flex-wrap items-center justify-end gap-2 border-t border-default bg-muted px-4 py-3">
      <slot name="footer" />
    </footer>
  </section>
</template>
