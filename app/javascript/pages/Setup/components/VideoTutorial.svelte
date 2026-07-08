<script lang="ts">
  import { Icon, ChevronRight } from "svelte-hero-icons";

  interface Props {
    label?: string;
    src: string;
    iframeTitle: string;
  }

  let { label = "Watch video tutorial", src, iframeTitle }: Props = $props();
</script>

<details class="group">
  <summary
    class="flex cursor-pointer items-center gap-2 text-sm text-secondary hover:text-surface-content"
  >
    <Icon
      src={ChevronRight}
      size="16"
      class="transition-transform group-open:rotate-90"
    />
    {label}
  </summary>
  <div class="mt-4 overflow-hidden rounded-lg border border-darkless">
    <iframe
      title={iframeTitle}
      width="100%"
      height="300"
      {src}
      frameborder="0"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowfullscreen
    ></iframe>
  </div>
</details>
