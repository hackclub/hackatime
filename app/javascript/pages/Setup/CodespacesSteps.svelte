<script lang="ts">
  import Button from "../../components/Button.svelte";
  import ScreenHeader from "./components/ScreenHeader.svelte";

  interface Props {
    onDone: () => void;
  }

  let { onDone }: Props = $props();

  const steps = [
    {
      title: "Go to the extension menu",
      image: "/images/setup/codespaces-step-1.png",
    },
    {
      title: 'Search for "Hackatime"',
      image: "/images/setup/codespaces-step-2.png",
    },
    {
      title: 'Install "Hackatime Time Tracker"',
      image: "/images/setup/codespaces-step-3.png",
    },
  ];
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader
    emoji="/images/emojis/ms-cloud.svg"
    title="Awesome!"
    subtitle="Now let's get Hackatime set up on Codespaces."
  />

  <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
    {#each steps as step, i}
      <div class="text-center">
        <div
          class="mx-auto flex size-9 items-center justify-center rounded-full border border-surface-300 bg-surface-100 font-semibold"
        >
          {i + 1}
        </div>
        <h2 class="mt-3 font-semibold text-balance">{step.title}</h2>
        <img
          src={step.image}
          alt={step.title}
          class="mt-4 w-full rounded-lg border border-surface-300"
        />
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
