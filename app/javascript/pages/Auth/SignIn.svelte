<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import AuthForm from "../Home/signedOut/AuthForm.svelte";

  let {
    hca_auth_path,
    slack_auth_path,
    email_auth_path,
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    continue_param,
  }: {
    hca_auth_path: string;
    slack_auth_path: string;
    email_auth_path: string;
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    continue_param?: string | null;
  } = $props();

  let previousTheme = $state<string | null>(null);

  $effect(() => {
    const html = document.documentElement;
    previousTheme = html.getAttribute("data-theme");
    html.setAttribute("data-theme", "gruvbox_dark");

    const colorSchemeMeta = document.querySelector("meta[name='color-scheme']");
    colorSchemeMeta?.setAttribute("content", "dark");

    return () => {
      if (previousTheme) {
        html.setAttribute("data-theme", previousTheme);
      }
    };
  });
</script>

<div
  class="min-h-screen w-full bg-darker text-surface-content flex flex-col items-center justify-center px-6"
>
  <div class="w-full max-w-md space-y-8">
    <div class="text-center">
      <Link href="/" class="inline-flex items-center gap-3 mb-8">
        <img
          src="/images/new-icon-rounded.png"
          class="w-12 h-12 rounded-lg"
          alt="Hackatime"
        />
        <span class="font-bold text-3xl tracking-tight">Hackatime</span>
      </Link>
      <h1 class="text-2xl font-semibold tracking-tight mb-2">
        Sign in to Hackatime
      </h1>
      <p class="text-secondary text-sm">
        Track your coding time. Own your metrics.
      </p>
    </div>

    <AuthForm
      {hca_auth_path}
      {slack_auth_path}
      {email_auth_path}
      {sign_in_email}
      {show_dev_tool}
      {dev_magic_link}
      {csrf_token}
      redirect_to="signin"
      {continue_param}
    />

    <div class="text-center">
      <Link
        href="/"
        class="text-sm text-secondary hover:text-primary transition-colors"
      >
        ← Back to home
      </Link>
    </div>
  </div>
</div>
