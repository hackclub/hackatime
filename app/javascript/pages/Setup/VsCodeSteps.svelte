<script lang="ts">
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import ScreenHeader from "./components/ScreenHeader.svelte";
  import step1 from "../../images/setup/vscode-step-1.avif";
  import step2 from "../../images/setup/vscode-step-2.avif";
  import step3 from "../../images/setup/vscode-step-3.avif";

  interface Props {
    onDone: () => void;
  }

  let { onDone }: Props = $props();

  // change this shit when you change the images!!!
  const steps = [
    {
      title: "Go to the extension menu",
      image: step1,
      width: 664,
      height: 712,
    },
    {
      title: 'Search for "Hackatime"',
      image: step2,
      width: 592,
      height: 234,
    },
    {
      title: 'Install "Hackatime Time Tracker"',
      image: step3,
      width: 1186,
      height: 352,
    },
  ];

  let zoomOpen = $state(false);
  let zoomIndex = $state(0);
  const zoomed = $derived(steps[zoomIndex]);

  function openZoom(index: number) {
    zoomIndex = index;
    zoomOpen = true;
  }
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader
    emoji="/images/emojis/ms-computer.svg"
    title="Awesome!"
    subtitle="Now let's install the Hackatime extension in your editor."
  />

  <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
    {#each steps as step, i}
      <div class="text-center">
        <div
          class="mx-auto flex size-9 items-center justify-center rounded-full border border-surface-300 bg-surface-100 font-semibold"
        >
          {i + 1}
        </div>
        <h2
          class="mt-3 flex min-h-[2lh] items-start justify-center font-semibold text-balance"
        >
          {step.title}
        </h2>
        <button
          type="button"
          onclick={() => openZoom(i)}
          aria-label={`Zoom in: ${step.title}`}
          class="group mt-4 flex aspect-4/3 w-full cursor-zoom-in items-center justify-center overflow-hidden rounded-lg border border-surface-300 bg-surface-100 p-3 transition-colors hover:border-surface-400 focus-visible:ring-2 focus-visible:ring-primary/70 focus-visible:outline-none"
        >
          <img
            src={step.image}
            alt={step.title}
            width={step.width}
            height={step.height}
            loading="lazy"
            decoding="async"
            class="max-h-full max-w-full object-contain transition-transform duration-200 group-hover:scale-[1.02]"
          />
        </button>
      </div>
    {/each}
  </div>

  <div class="text-center">
    <p class="text-base font-semibold text-balance sm:text-lg">
      Once you go through setup (you'll have to authorize VSCode):
    </p>
    <div class="mt-6">
      <Button variant="dark" size="lg" onclick={onDone}>I'm done!</Button>
    </div>
  </div>
</div>

<Modal bind:open={zoomOpen} title={zoomed.title} maxWidth="max-w-5xl" hasBody>
  {#snippet body()}
    <img
      src={zoomed.image}
      alt={zoomed.title}
      width={zoomed.width}
      height={zoomed.height}
      class="mx-auto h-auto w-full rounded-lg border border-surface-300"
    />
  {/snippet}
</Modal>
