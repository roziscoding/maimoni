<script setup lang="ts">
import type { SessionEntry } from '@maimoni/shared'

const toast = useToast()
const { data: sessions, error, refresh } = await useFetch<SessionEntry[]>('/api/sessions', { key: 'sessions' })

/** ID of the session being ended, or `others` for all but the current one. */
const ending = ref<string | null>(null)

async function end(id?: string) {
  ending.value = id ?? 'others'
  try {
    await $fetch(id ? `/api/sessions/${id}` : '/api/sessions', { method: 'DELETE' })
    toast.add({ title: id ? 'Sessão encerrada' : 'Outras sessões encerradas', color: 'success', icon: 'i-lucide-check' })
  }
  catch (err) {
    toast.add({ title: 'Não foi possível encerrar', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    await refresh()
    ending.value = null
  }
}
</script>

<template>
  <SettingsSection title="Sessões" description="Onde sua conta está conectada. Encerre as que você não reconhece ou não usa mais.">
    <ul v-if="sessions" class="divide-y divide-default">
      <li v-for="session in sessions" :key="session.id" class="flex items-center gap-3 px-4 py-3">
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-medium text-highlighted">
            {{ deviceLabel(session.userAgent) }}
            <UBadge v-if="session.current" label="Esta sessão" color="neutral" variant="subtle" size="sm" class="ml-1" />
          </p>
          <p class="truncate text-sm text-muted">
            Entrou em {{ formatDateTime(session.createdAt) }}<template v-if="session.ipAddress">
              · {{ session.ipAddress }}
            </template>
          </p>
        </div>
        <UButton
          v-if="!session.current"
          label="Encerrar"
          color="neutral"
          variant="subtle"
          size="sm"
          :loading="ending === session.id"
          :disabled="ending !== null"
          @click="end(session.id)"
        />
      </li>
    </ul>
    <p v-else-if="error" class="px-4 py-3 text-sm text-error">
      Não foi possível carregar as sessões: {{ errorMessage(error) }}
    </p>

    <template v-if="sessions && sessions.length > 1" #footer>
      <UButton
        label="Encerrar todas as outras"
        icon="i-lucide-log-out"
        color="neutral"
        variant="outline"
        :loading="ending === 'others'"
        :disabled="ending !== null"
        @click="end()"
      />
    </template>
  </SettingsSection>
</template>
