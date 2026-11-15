<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import HackClubLogo from "../../components/HackClubLogo.svelte";
  import { hcaLinkPrompts, sessions } from "../../api";

  let {
    skippable,
    continue_param,
  }: {
    skippable: boolean;
    continue_param?: string | null;
  } = $props();

  const query = $derived(
    continue_param ? { query: { continue: continue_param } } : undefined,
  );
  const linkPath = $derived(
    query ? sessions.hcaNew.path(query) : sessions.hcaNew.path(),
  );
  const skipPath = $derived(
    query ? hcaLinkPrompts.destroy.path(query) : hcaLinkPrompts.destroy.path(),
  );
</script>

<svelte:head>
  <title>Link your Hack Club account | Hackatime</title>
</svelte:head>

<div class="mx-auto w-full max-w-2xl py-8">
  <header class="mb-6">
    <h1
      class="text-2xl sm:text-3xl font-bold tracking-tight text-surface-content text-balance"
    >
      Link your Hack Club account
    </h1>
    <p class="mt-1 text-muted text-pretty">
      Hackatime is moving to Hack Club sign-in only. Slack and email sign-in
      will be switched off soon.
    </p>
  </header>

  <div class="rounded-2xl border border-surface-200 bg-dark p-6">
    <p class="text-sm leading-relaxed text-surface-content text-pretty">
      {#if skippable}
        Link a Hack Club account now and you'll keep access to this Hackatime
        account after the switch.
      {:else}
        Link a Hack Club account to carry on. It's how you'll sign in to this
        Hackatime account from now on.
      {/if}
    </p>

    <ul class="mt-4 space-y-1.5 text-sm leading-relaxed text-muted text-pretty">
      <li>
        Your editors keep tracking time either way. This only changes how you
        sign in on the website.
      </li>
      <li>
        No Hack Club account yet? You can make one on the next screen with the
        email you use here.
      </li>
      <li>
        Stuck? Ask in #hackatime-help on the
        <a
          href="https://hackclub.slack.com"
          class="underline hover:text-surface-content">Hack Club Slack</a
        >.
      </li>
    </ul>
  </div>

  <div class="mt-5 grid grid-cols-1 items-center gap-3 sm:grid-cols-[1fr_auto]">
    <Button
      href={linkPath}
      native
      variant="primary"
      class="w-full sm:order-last sm:w-auto"
    >
      <HackClubLogo class="mr-2 h-5 w-5" />
      Link Hack Club account
    </Button>

    {#if skippable}
      <Form action={skipPath} method="delete" class="w-full">
        <Button type="submit" variant="dark" class="w-full sm:w-auto">
          Not now
        </Button>
      </Form>
    {:else}
      <Form action={sessions.destroy.path()} method="delete" class="w-full">
        <Button type="submit" variant="dark" class="w-full sm:w-auto">
          Sign out
        </Button>
      </Form>
    {/if}
  </div>
</div>
