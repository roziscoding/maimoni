<template>
  <!-- Nothing can be added without a currency to add it in. -->
  <UAlert
    color="warning"
    variant="subtle"
    icon="i-lucide-coins"
    title="Nenhuma moeda ativa"
    description="Itens e gastos são registrados em uma moeda. Adicione uma moeda nas configurações para começar."
    :actions="[{ label: 'Abrir configurações', color: 'neutral', variant: 'outline', to: '/settings' }]"
  />
</template>
