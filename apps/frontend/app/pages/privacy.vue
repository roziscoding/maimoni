<script setup lang="ts">
// Public privacy policy, linked from App Store Connect and from the apps' settings. Keep it in
// sync with what the apps and the backend actually collect and call.
definePageMeta({ layout: false })

useHead({ title: 'Política de privacidade · maimoni' })

const CONTACT = 'privacidade@roz.ninja'
</script>

<template>
  <main class="mx-auto max-w-2xl space-y-8 px-4 py-12 text-default">
    <header class="space-y-2">
      <h1 class="text-2xl font-semibold text-highlighted">
        Política de privacidade
      </h1>
      <p class="text-sm text-muted">
        Atualizada em 27 de novembro de 2026.
      </p>
    </header>

    <p>
      O maimoni organiza as contas do mês e mostra quanto dá para gastar por dia. Ele funciona no
      navegador e nos apps para Android e iPhone. Esta página diz quais dados ele guarda, onde e com
      quem eles são compartilhados.
    </p>

    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-highlighted">
        Sem conta
      </h2>
      <p>
        No app, dá para usar o maimoni sem conta. Nesse modo os meses, itens, gastos e moedas ficam
        só no aparelho e nada é enviado ao servidor do maimoni.
      </p>
      <ul class="list-disc space-y-2 pl-5">
        <li>
          Se você ativar o backup em Ajustes, uma cópia dos dados entra no backup do iCloud ou do
          Google, conforme a conta configurada no celular.
        </li>
        <li>
          Para converter moedas, o app consulta as cotações em
          <span class="font-mono text-sm">api.frankfurter.dev</span> ou
          <span class="font-mono text-sm">open.er-api.com</span>. A consulta leva só os códigos das
          moedas.
        </li>
      </ul>
    </section>

    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-highlighted">
        Com conta
      </h2>
      <p>
        Quem entra numa conta tem estes dados guardados no servidor do maimoni:
      </p>
      <ul class="list-disc space-y-2 pl-5">
        <li>nome e e-mail;</li>
        <li>a senha, guardada só como hash, para quem entra com e-mail e senha;</li>
        <li>a chave pública de cada passkey cadastrada;</li>
        <li>os meses, itens, gastos, template e moedas que você cadastra;</li>
        <li>as sessões abertas, com o endereço IP e o navegador ou app de cada uma.</li>
      </ul>
      <p>
        Esses dados servem só para o maimoni funcionar: entrar na conta, mostrar seus meses e enviar
        o e-mail de redefinição de senha. O maimoni não tem anúncios, não usa ferramentas de
        análise e não rastreia você em outros apps ou sites.
      </p>
    </section>

    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-highlighted">
        Serviços de terceiros
      </h2>
      <ul class="list-disc space-y-2 pl-5">
        <li>
          Ao entrar com o Google ou com a Apple, o provedor informa ao maimoni seu nome e e-mail. A
          Apple pode entregar um e-mail de encaminhamento no lugar do seu.
        </li>
        <li>
          O e-mail de redefinição de senha é enviado pela Resend, que recebe o seu endereço e o link
          do e-mail.
        </li>
        <li>
          O app baixa as fontes do texto do Google Fonts, que recebe o endereço IP do aparelho.
        </li>
        <li>
          O servidor consulta as cotações das moedas nos mesmos serviços do modo sem conta, sem
          nenhum dado seu.
        </li>
      </ul>
      <p>
        Nenhum dado é vendido. Fora dos serviços acima, nenhum dado é repassado a outras empresas.
      </p>
    </section>

    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-highlighted">
        Acesso, cópia e exclusão
      </h2>
      <ul class="list-disc space-y-2 pl-5">
        <li>Em Ajustes, você exporta todos os seus dados num arquivo.</li>
        <li>Também em Ajustes, você vê as sessões abertas e encerra qualquer uma delas.</li>
        <li>
          Os dados da conta ficam guardados até a conta ser excluída. Para excluir a conta e tudo o
          que ela guarda, escreva para
          <ULink :to="`mailto:${CONTACT}`" class="font-medium text-primary">
            {{ CONTACT }}
          </ULink>
          a partir do e-mail da conta.
        </li>
        <li>No modo sem conta, desinstalar o app apaga os dados do aparelho.</li>
      </ul>
    </section>

    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-highlighted">
        Contato
      </h2>
      <p>
        Dúvidas sobre esta política ou sobre os seus dados:
        <ULink :to="`mailto:${CONTACT}`" class="font-medium text-primary">
          {{ CONTACT }}
        </ULink>.
        Quando a política mudar, a data no topo desta página muda junto.
      </p>
    </section>
  </main>
</template>
