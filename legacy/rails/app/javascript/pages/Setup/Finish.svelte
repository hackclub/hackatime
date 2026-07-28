<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { Icon, InformationCircle } from "svelte-hero-icons";
  import { onMount } from "svelte";
  import confetti from "canvas-confetti";
  import Button from "../../components/Button.svelte";

  interface Props {
    returnUrl?: string;
    returnButtonText: string;
    hardware?: boolean;
  }

  let { returnUrl, returnButtonText, hardware = false }: Props = $props();

  let agreed = $state(false);

  // Celebrate reaching the finish screen with a confetti burst.
  onMount(() => {
    const reduceMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    if (reduceMotion) return;

    const fire = (particleRatio: number, opts: confetti.Options) =>
      confetti({
        origin: { y: 0.6 },
        particleCount: Math.floor(200 * particleRatio),
        ...opts,
      });

    fire(0.25, { spread: 26, startVelocity: 55 });
    fire(0.2, { spread: 60 });
    fire(0.35, { spread: 100, decay: 0.91, scalar: 0.8 });
    fire(0.1, { spread: 120, startVelocity: 25, decay: 0.92, scalar: 1.2 });
    fire(0.1, { spread: 120, startVelocity: 45 });
  });
</script>

<div class="mx-auto max-w-2xl">
  {#if hardware}
    <div class="mb-6 flex gap-3 rounded-xl border border-blue/20 bg-blue/5 p-5">
      <Icon
        src={InformationCircle}
        size="22"
        class="mt-0.5 shrink-0 text-blue"
      />
      <div class="text-sm">
        <p class="mb-1 font-semibold text-blue">No code editor setup needed</p>
        <p class="text-secondary">
          Since you're joining through a hardware program, you don't need to set
          up a code editor right now. You can always come back to this setup
          page from your dashboard.
        </p>
      </div>
    </div>
  {/if}

  <div
    class="rounded-xl border border-surface-300 bg-surface-100 p-6 text-center"
  >
    <img src="/images/emojis/ms-tada.svg" alt="" class="mx-auto mb-3 size-12" />
    <h1 class="mb-2 text-lg font-semibold">You're all set!</h1>
    <p class="mb-8 text-sm">Hackatime is configured and tracking your code.</p>

    <div
      class="mb-8 rounded-xl border border-yellow/40 bg-yellow/10 p-6 text-left text-surface-content"
    >
      <h2 class="mb-2 font-semibold text-yellow">Fair Play Policy</h2>
      <p class="mb-3 text-sm">
        Hackatime tracks the time you legitimately spend working on projects.
        However, some activities may be considered fraud if they do not align
        with the fair play policy.
      </p>
      <p class="mb-3 text-sm">
        Fraud means trying to make it look like you're coding when you are not,
        including using scripts, bots, manipulated heartbeats, spoofed editor
        activity or API abuse.
      </p>
      <p class="text-sm">
        We have a zero-tolerance policy for fraud. Attempting to cheat the
        system can result in a <strong>permanent ban</strong> from Hackatime and
        all Hack Club events. Read the full policy on the
        <a
          href="https://fraud.hackclub.com/fairplay"
          target="_blank"
          rel="noreferrer"
          class="font-semibold underline"
        >
          Fraud page</a
        >.
      </p>
      <p class="mt-3 text-sm">
        Hack Club is a non-profit running on donations, so please keep your
        activity honest and respect the community.
      </p>

      <div class="mt-2 flex justify-center border-t border-yellow/10 pt-6">
        <label class="flex cursor-pointer items-center gap-3 select-none">
          <Checkbox.Root
            bind:checked={agreed}
            class="inline-flex h-5 w-5 min-w-5 items-center justify-center rounded border border-darkless bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
          >
            {#snippet children({ checked })}
              <span
                class={checked ? "text-xs font-bold leading-none" : "hidden"}
                >✓</span
              >
            {/snippet}
          </Checkbox.Root>
          <span class="font-medium">I understand and agree to the rules</span>
        </label>
      </div>
    </div>

    <Button
      href={returnUrl ?? "/"}
      size="xl"
      class="w-full text-center font-semibold sm:w-auto {agreed
        ? ''
        : 'pointer-events-none cursor-not-allowed opacity-50'}"
    >
      {returnUrl ? returnButtonText : "Let's get going!"}
    </Button>
  </div>
</div>
