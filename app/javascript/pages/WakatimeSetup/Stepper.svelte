<script lang="ts">
  import Checkmark from "hcicons-svelte/checkmark";

  interface Props {
    currentStep: number;
  }

  let { currentStep }: Props = $props();

  const steps = [
    { number: 1, label: "Install" },
    { number: 2, label: "Editor" },
    { number: 3, label: "Plugin" },
    { number: 4, label: "Finish" },
  ];

  const circleClass = (n: number) =>
    currentStep > n
      ? "bg-green border-green text-darker"
      : currentStep === n
        ? "bg-primary border-primary text-on-primary"
        : "bg-dark border-darkless text-secondary";
</script>

<div class="mb-10">
  <div
    class="relative flex items-center justify-between w-full max-w-2xl mx-auto"
  >
    <div class="absolute top-5 left-5 right-5 h-0.5 bg-darkless -z-10"></div>

    {#each steps as step}
      <div class="flex flex-col items-center gap-2 z-10">
        <div
          class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold border-2 transition-colors duration-200 {circleClass(
            step.number,
          )}"
        >
          {#if currentStep > step.number}
            <Checkmark size={20} />
          {:else}
            {step.number}
          {/if}
        </div>
        <span
          class="text-xs font-medium {currentStep === step.number
            ? 'text-surface-content'
            : 'text-secondary'}">{step.label}</span
        >
      </div>
    {/each}
  </div>
</div>
