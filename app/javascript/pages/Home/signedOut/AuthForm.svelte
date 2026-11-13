<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import HackClubLogo from "../../../components/HackClubLogo.svelte";
  import { sessions } from "../../../api";
  import Slack from "hcicons-svelte/slack";

  let {
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    redirect_to,
    continue_param,
  }: {
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    redirect_to?: string;
    continue_param?: string | null;
  } = $props();

  const query = $derived(
    continue_param ? { query: { continue: continue_param } } : undefined,
  );
  const hcaAuthPath = $derived(
    query ? sessions.hcaNew.path(query) : sessions.hcaNew.path(),
  );
  const slackAuthPath = $derived(
    query ? sessions.slackNew.path(query) : sessions.slackNew.path(),
  );
  const emailAuthPath = sessions.email.path();

  let isSigningIn = $state(false);
  let showOlderSignIn = $state(false);
</script>

<div class="w-full max-w-md space-y-4">
  {#if sign_in_email}
    <div
      class="rounded-2xl border border-surface-200 bg-surface p-8 text-center space-y-2"
    >
      <p class="text-surface-content font-medium">Check your email!</p>
      <p class="text-secondary text-sm">
        If that email has a Hackatime account, we sent it a sign-in link. Check
        your spam if you can't see it!
      </p>
      <p class="text-secondary text-sm">
        New to Hackatime?
        <a href={hcaAuthPath} class="underline hover:text-surface-content"
          >Sign in with Hack Club</a
        > instead.
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
    <a
      href={hcaAuthPath}
      onclick={() => (isSigningIn = true)}
      class="w-full flex items-center justify-center gap-3 px-6 py-3.5 rounded-xl bg-primary text-on-primary font-medium hover:opacity-90 transition-all"
    >
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
    </a>

    <div class="pt-1 text-center">
      <Button
        type="button"
        unstyled
        aria-expanded={showOlderSignIn}
        aria-controls="older-sign-in"
        class="text-sm text-secondary underline hover:text-surface-content transition-colors"
        onclick={() => (showOlderSignIn = !showOlderSignIn)}
      >
        Signing in to an older account?
      </Button>
    </div>

    {#if showOlderSignIn}
      <div id="older-sign-in" class="space-y-4">
        <p class="text-sm text-muted text-center">
          Accounts made with Slack or email can still sign in that way for now.
          Once you're in, link your Hack Club account to keep access.
        </p>

        <a
          href={slackAuthPath}
          class="w-full flex items-center justify-center gap-3 px-6 py-3.5 rounded-xl bg-surface border border-surface-200 text-surface-content font-medium hover:bg-surface-100 transition-all"
        >
          <Slack size={20} />
          <span>Sign in with Slack</span>
        </a>

        <form method="post" action={emailAuthPath}>
          <input type="hidden" name="authenticity_token" value={csrf_token} />
          {#if redirect_to}
            <input type="hidden" name="redirect_to" value={redirect_to} />
          {/if}
          {#if continue_param}
            <input type="hidden" name="continue" value={continue_param} />
          {/if}
          <div class="flex gap-2">
            <input
              type="email"
              name="email"
              placeholder="you@email.com"
              required
              class="flex-1 bg-surface text-surface-content placeholder-muted rounded-xl py-3.5 px-4 focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all border border-surface-200 focus:border-primary text-sm"
            />
            <Button
              type="submit"
              unstyled
              class="px-5 py-3.5 bg-surface border border-primary text-primary rounded-xl hover:bg-primary hover:text-on-primary transition-all text-sm font-medium"
            >
              Send link
            </Button>
          </div>
        </form>
      </div>
    {/if}
  {/if}
</div>
