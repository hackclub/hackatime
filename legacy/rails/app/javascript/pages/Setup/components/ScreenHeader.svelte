<script lang="ts">
  interface Props {
    emoji: string;
    title: string;
    subtitle?: string;
    html?: string;
  }

  let { emoji, title, subtitle, html }: Props = $props();
</script>

<div class="text-center">
  <!-- <img src={emoji} alt="" class="mx-auto mb-4 size-12 sm:size-14" /> -->
  <h1
    class="mx-auto max-w-[35ch] text-2xl font-semibold tracking-tight text-balance sm:text-3xl"
  >
    {title}
  </h1>
  {#if subtitle}
    <p class="mx-auto mt-3 max-w-[48ch] text-base text-pretty text-secondary">
      {subtitle}
    </p>
  {/if}
  {#if html}
    <p class="mx-auto mt-3 max-w-[48ch] text-base text-pretty text-secondary">
      {@html html}
    </p>
  {/if}
</div>
