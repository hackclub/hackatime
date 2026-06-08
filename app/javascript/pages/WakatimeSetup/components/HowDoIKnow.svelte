<script lang="ts">
  import VideoTutorial from "./VideoTutorial.svelte";

  interface Props {
    image?: string;
    description?: string;
  }

  let {
    image,
    description = "You'll see a WakaTime icon and time spent coding in your status bar:",
  }: Props = $props();
</script>

<VideoTutorial label="How do I know it's working?">
  <p class="text-sm mb-3 text-secondary">{@html description}</p>
  {#if image}
    <img
      src={image}
      alt="WakaTime status bar"
      class="rounded-lg border border-darkless"
    />
  {/if}
</VideoTutorial>
