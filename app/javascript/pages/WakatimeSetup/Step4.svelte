<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { Link } from "@inertiajs/svelte";
  import { Icon, InformationCircle } from "svelte-hero-icons";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";

  interface Props {
    return_url?: string;
    return_button_text: string;
    hardware?: boolean;
  }

  let { return_url, return_button_text, hardware = false }: Props = $props();

  let agreed = $state(false);
</script>

<svelte:head>
  <title>Setup Complete - Step 4</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={4} />

    {#if hardware}
      <div
        class="bg-blue/5 border border-blue/20 rounded-xl p-5 mb-6 flex gap-3"
      >
        <Icon
          src={InformationCircle}
          size="22"
          class="text-blue shrink-0 mt-0.5"
        />
        <div class="text-sm">
          <p class="font-semibold text-blue mb-1">
            No code editor setup needed
          </p>
          <p class="text-secondary">
            Since you're joining through a hardware program, you don't need to
            set up a code editor right now. If you'd like to connect one later,
            you can always do so from
            <Link
              href="/my/wakatime_setup"
              class="text-primary underline hover:text-primary/80"
              >My&nbsp;Setup</Link
            > on your dashboard.
          </p>
        </div>
      </div>
    {/if}

    <div class="bg-dark border border-darkless rounded-xl p-6 text-center">
      <h1 class="text-lg font-bold mb-2">You're all set!</h1>
      <p class="mb-8 text-sm">
        Hackatime is configured and tracking your code.
      </p>

      <div class="bg-yellow text-black rounded-xl p-6 mb-8 text-left">
        <h3 class="font-bold mb-2">Fair Play Policy</h3>
        <p class="text-sm mb-3">
          Hackatime tracks the time you genuinely spend writing code. Fraud
          means trying to make it look like you're coding when you are not,
          including using scripts, bots, manipulated heartbeats, spoofed editor
          activity, or API abuse.
        </p>
        <p class="text-sm">
          We have a zero-tolerance policy for fraud. Attempting to cheat the
          system can result in a <strong>permanent ban</strong> from Hackatime
          and all Hack Club events. Read the full policy on the
          <a
            href="https://fraud.hackclub.com/fairplay"
            target="_blank"
            rel="noreferrer"
            class="underline font-semibold"
          >
            Fraud page</a
          >.
        </p>
        <p class="text-sm mt-3">
          Hack Club is a non-profit running on donations, so please keep your
          activity honest and respect the community.
        </p>

        <div class="mt-2 pt-6 border-t border-yellow/10 flex justify-center">
          <label
            class="flex items-center gap-3 cursor-pointer select-none group"
          >
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
        href={return_url ?? "/"}
        size="xl"
        class="w-full sm:w-auto transition-all font-semibold transform active:scale-[0.98] text-center {agreed
          ? ''
          : 'opacity-50 cursor-not-allowed pointer-events-none'}"
      >
        {return_url ? return_button_text : "Let's get going!"}
      </Button>
    </div>
  </div>
</div>
