<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import AuthForm from "../Home/signedOut/AuthForm.svelte";

  let {
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    continue_param,
  }: {
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    continue_param?: string | null;
  } = $props();

  $effect(() => {
    const html = document.documentElement;
    const previousTheme = html.getAttribute("data-theme");
    html.setAttribute("data-theme", "rose");
    document
      .querySelector("meta[name='color-scheme']")
      ?.setAttribute("content", "dark");

    return () => {
      if (previousTheme) html.setAttribute("data-theme", previousTheme);
    };
  });
</script>

<svelte:head>
  <title>Sign in - Hackatime</title>
</svelte:head>

<div
  class="min-h-dvh w-full bg-darker text-surface-content flex flex-col px-6 py-8"
>
  <div class="flex flex-1 items-center justify-center">
    <div class="w-full max-w-md">
      <div class="text-center">
        <Link href="/" class="inline-flex items-center gap-3 mb-8">
          <img
            src="/images/new-icon-rounded.png"
            class="w-12 h-12 rounded-lg"
            alt="Hackatime"
          />
          <span class="font-bold text-3xl tracking-tight">Hackatime</span>
        </Link>
      </div>

      <AuthForm
        {sign_in_email}
        {show_dev_tool}
        {dev_magic_link}
        {csrf_token}
        redirect_to="signin"
        {continue_param}
      />

      <div class="text-center mt-4">
        <Link
          href="/"
          class="text-sm text-secondary hover:text-primary transition-colors"
        >
          ← Back to home
        </Link>
      </div>
    </div>
  </div>

  <p
    class="mx-auto w-full max-w-md pt-8 text-center text-secondary text-sm text-pretty"
  >
    By signing in, you agree to the <a
      class="text-primary"
      href="https://hackclub.com/privacy-and-terms#hack-club-standard-terms-and-conditions"
      >Terms of Service</a
    >
    and
    <a
      class="text-primary"
      href="https://hackclub.com/privacy-and-terms#hack-club-privacy-notice"
      >Privacy Policy</a
    >.
  </p>
</div>
