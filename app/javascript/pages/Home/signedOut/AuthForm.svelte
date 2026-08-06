<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import HackClubLogo from "../../../components/HackClubLogo.svelte";
  import { sessions } from "../../../api";

  let {
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    continue_param,
    login_hint,
    pending_hca,
  }: {
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    continue_param?: string | null;
    login_hint?: string | null;
    pending_hca?: { email: string } | null;
  } = $props();

  const query = $derived(
    continue_param ? { query: { continue: continue_param } } : undefined,
  );
  const hcaAuthPath = $derived(
    query ? sessions.hcaNew.path(query) : sessions.hcaNew.path(),
  );
  let isSigningIn = $state(false);
</script>

<div class="w-full max-w-md space-y-4">
  {#if pending_hca}
    <div class="rounded-2xl border border-surface-200 bg-surface p-6 space-y-4">
      <div>
        <p class="font-medium">Continue as {pending_hca.email}</p>
        <p class="text-sm text-secondary">
          Create a new account or prove ownership of an older Hackatime account.
        </p>
      </div>
      <form method="post" action={sessions.hcaAccount.path()}>
        <input type="hidden" name="authenticity_token" value={csrf_token} />
        <Button type="submit" class="w-full">Create new account</Button>
      </form>
      <form method="post" action={sessions.slackNew.path()}>
        <input type="hidden" name="authenticity_token" value={csrf_token} />
        <Button type="submit" variant="surface" class="w-full"
          >Recover with Slack</Button
        >
      </form>
      <form
        method="post"
        action={sessions.hcaRecovery.path()}
        class="space-y-2"
      >
        <input type="hidden" name="authenticity_token" value={csrf_token} />
        <label for="old-email" class="text-sm"
          >Email used on your old Hackatime account</label
        >
        <input
          id="old-email"
          type="email"
          name="email"
          required
          class="w-full bg-surface text-surface-content rounded-xl py-3 px-4 border border-surface-200"
        />
        <Button type="submit" variant="surface" class="w-full"
          >Email recovery link</Button
        >
      </form>
      <form method="post" action={sessions.hcaCancel.path()}>
        <input type="hidden" name="_method" value="delete" />
        <input type="hidden" name="authenticity_token" value={csrf_token} />
        <Button type="submit" variant="dark" class="w-full"
          >Cancel and restart</Button
        >
      </form>
    </div>
  {:else if sign_in_email}
    <div
      class="rounded-2xl border border-surface-200 bg-surface p-8 text-center space-y-2"
    >
      <p class="text-surface-content font-medium">Check your email!</p>
      <p class="text-secondary text-sm">
        We sent a sign-in link to your inbox. Check your spam if you can't see
        it!
      </p>
      {#if show_dev_tool && dev_magic_link}
        <a
          href={dev_magic_link}
          class="text-xs text-secondary underline hover:text-surface-content"
        >
          Dev: Open Link
        </a>
      {/if}
    </div>
  {:else}
    <form
      method="post"
      action={hcaAuthPath}
      onsubmit={() => (isSigningIn = true)}
      class="space-y-3"
    >
      <input type="hidden" name="authenticity_token" value={csrf_token} />
      <input
        type="email"
        name="login_hint"
        value={login_hint || ""}
        placeholder="Your Hack Club Account email"
        class="w-full bg-surface text-surface-content rounded-xl py-3.5 px-4 border border-surface-200"
      />
      <p class="text-xs text-secondary">
        We'll hand this email to Hack Club Account. Hackatime does not send a
        sign-in link.
      </p>
      <Button type="submit" class="w-full gap-3 py-3.5" disabled={isSigningIn}>
        {#if isSigningIn}
          <svg class="h-5 w-5 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            ></circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
          </svg>
        {:else}
          <HackClubLogo class="h-5 w-5" />
        {/if}
        <span>Sign in with Hack Club</span>
      </Button>
    </form>
  {/if}
</div>
