<script setup lang="ts">
import type { SessionEntry } from '@maimoni/shared'

const toast = useToast()
const { data: sessions, error, refresh } = await useFetch<SessionEntry[]>('/api/sessions', { key: 'sessions' })

/** ID of the session being ended, or `others` for all but the current one. */
const ending = ref<string | null>(null)
/** What the user asked to end and hasn't confirmed yet: one session, or `others`. */
const asking = ref<SessionEntry | 'others' | null>(null)

async function end(id?: string) {
  ending.value = id ?? 'others'
  try {
    await $fetch(id ? `/api/sessions/${id}` : '/api/sessions', { method: 'DELETE' })
    toast.add({ title: id ? 'Sessão encerrada' : 'Outras sessões encerradas', color: 'success', icon: 'i-lucide-check' })
  }
  catch (err) {
    toast.add({ title: id ? 'Não foi possível encerrar a sessão' : 'Não foi possível encerrar as outras sessões', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    await refresh()
    ending.value = null
    asking.value = null
  }
}

const confirming = computed({
  get: () => asking.value !== null,
  // Closing the dialog while the request runs would leave it without feedback.
  set: (open) => {
    if (!open && ending.value === null)
      asking.value = null
  },
})

/** The dialog says what ending does to the device, since that is the moment the user decides. */
const confirmation = computed(() => {
  if (asking.value === 'others') {
    return {
      title: 'Encerrar as outras sessões?',
      description: 'Todos os outros dispositivos serão desconectados da conta. Para voltar a usá-la, será necessário entrar novamente em cada um.',
      action: 'Encerrar as outras sessões',
    }
  }
  return {
    title: asking.value ? `Encerrar a sessão em ${deviceLabel(asking.value.userAgent)}?` : '',
    description: 'O dispositivo será desconectado da conta. Para voltar a usá-la nele, será necessário entrar novamente.',
    action: 'Encerrar sessão',
  }
})

function confirm() {
  if (asking.value)
    end(asking.value === 'others' ? undefined : asking.value.id)
}
</script>

<template>
  <SettingsSection title="Sessões" description="Dispositivos conectados à conta.">
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
          :disabled="ending !== null"
          @click="asking = session"
        />
      </li>
    </ul>
    <p v-else-if="error" class="px-4 py-3 text-sm text-error">
      Não foi possível carregar as sessões: {{ errorMessage(error) }}
    </p>

    <template v-if="sessions && sessions.length > 1" #footer>
      <UButton
        label="Encerrar as outras sessões"
        icon="i-lucide-log-out"
        color="neutral"
        variant="outline"
        :disabled="ending !== null"
        @click="asking = 'others'"
      />
    </template>

    <UModal v-model:open="confirming" :title="confirmation.title" :description="confirmation.description" :ui="{ footer: 'justify-end' }">
      <template #footer>
        <UButton label="Cancelar" color="neutral" variant="outline" :disabled="ending !== null" @click="confirming = false" />
        <UButton :label="confirmation.action" color="error" icon="i-lucide-log-out" :loading="ending !== null" @click="confirm" />
      </template>
    </UModal>
  </SettingsSection>
</template>
