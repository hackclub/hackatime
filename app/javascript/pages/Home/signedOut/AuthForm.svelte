<script lang="ts">
  import Button from "../../../components/Button.svelte";

  let {
    hca_auth_path,
    slack_auth_path,
    email_auth_path,
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    redirect_to,
    continue_param,
  }: {
    hca_auth_path: string;
    slack_auth_path: string;
    email_auth_path: string;
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    redirect_to?: string;
    continue_param?: string | null;
  } = $props();

  let isSigningIn = $state(false);
</script>

<div class="w-full max-w-md space-y-4">
  {#if sign_in_email}
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
    <a
      href={hca_auth_path}
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
        <img src="/images/icon-rounded.png" class="h-5 w-5" alt="Hack Club" />
      {/if}
      <span>Sign in with Hack Club</span>
    </a>

    <a
      href={slack_auth_path}
      class="w-full flex items-center justify-center gap-3 px-6 py-3.5 rounded-xl bg-surface border border-surface-200 text-surface-content font-medium hover:bg-surface-100 transition-all"
    >
      <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
        <path
          d="M6 15a2 2 0 0 1-2 2a2 2 0 0 1-2-2a2 2 0 0 1 2-2h2zm1 0a2 2 0 0 1 2-2a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2a2 2 0 0 1-2-2zm2-8a2 2 0 0 1-2-2a2 2 0 0 1 2-2a2 2 0 0 1 2 2v2zm0 1a2 2 0 0 1 2 2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2a2 2 0 0 1 2-2zm8 2a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2h-2zm-1 0a2 2 0 0 1-2 2a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2a2 2 0 0 1 2 2zm-2 8a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2v-2zm0-1a2 2 0 0 1-2-2a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2a2 2 0 0 1-2 2z"
        />
      </svg>
      <span>Sign in with Slack</span>
    </a>

    <div class="flex items-center gap-4 py-1">
      <div class="flex-1 h-px bg-surface-200"></div>
      <span class="text-xs text-muted uppercase tracking-wider">or</span>
      <div class="flex-1 h-px bg-surface-200"></div>
    </div>

    <form method="post" action={email_auth_path} data-turbo="false">
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
  {/if}
</div>
