<script lang="ts">
  interface Props {
    currentStep: number;
  }

  let { currentStep }: Props = $props();

  const steps = [
    { number: 1, label: "Install" },
    { number: 2, label: "Editor" },
    { number: 3, label: "Plugin" },
    { number: 4, label: "Finish" }
  ];
</script>

<div class="mb-10">
  <div class="relative flex items-center justify-between w-full max-w-2xl mx-auto">
    <div class="absolute top-5 left-0 w-full h-0.5 bg-darkless -z-10"></div>

    {#each steps as step}
      <div class="flex flex-col items-center gap-2 bg-darker z-10 px-2">
        <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold border-2 transition-colors duration-200
          {currentStep > step.number ? 'bg-green border-green text-darker' : 
           currentStep === step.number ? 'bg-primary border-primary text-on-primary' : 
           'bg-dark border-darkless text-secondary'}">
          {#if currentStep > step.number}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
          {:else}
            {step.number}
          {/if}
        </div>
        <span class="text-xs font-medium {currentStep === step.number ? 'text-surface-content' : 'text-secondary'}">{step.label}</span>
      </div>
    {/each}
  </div>
</div>
