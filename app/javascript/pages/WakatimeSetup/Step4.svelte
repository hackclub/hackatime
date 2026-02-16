<script lang="ts">
  import { Checkbox } from "bits-ui";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";

  interface Props {
    return_url?: string;
    return_button_text: string;
  }

  let { return_url, return_button_text }: Props = $props();

  let agreed = $state(false);
</script>

<svelte:head>
  <title>Setup Complete - Step 4</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={4} />

    <div class="bg-dark border border-darkless rounded-xl p-6 text-center">
      <h1 class="text-lg font-bold mb-2">You're all set!</h1>
      <p class="mb-8 text-sm">
        Hackatime is configured and tracking your code.
      </p>

      <div class="bg-yellow text-black rounded-xl p-6 mb-8 text-left">
        <div class="flex items-start gap-4">
          <div>
            <h3 class="font-bold mb-2">Fair Play Policy</h3>
            <p class="text-sm mb-3">
              We have sophisticated measures to detect time manipulation.
              Attempting to cheat the system will result in a <strong
                >permanent ban</strong
              > from Hackatime and all Hack Club events.
            </p>
            <p class="text-sm">
              We are a non-profit running on donations - please respect the
              community and play fair!
            </p>
          </div>
        </div>

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

      <div class="flex flex-col sm:flex-row gap-4 justify-center">
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
</div>
