<script lang="ts">
  import type { Snippet } from "svelte";
  import ScreenHeader from "./ScreenHeader.svelte";

  interface Props {
    emoji: string;
    title: string;
    subtitle?: string;
    question: string;
    children: Snippet;
  }

  let { emoji, title, subtitle, question, children }: Props = $props();
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader {emoji} {title} {subtitle} />

  <div>
    <h2
      class="mx-auto max-w-[40ch] text-center text-base font-semibold text-balance sm:text-lg"
    >
      {question}
    </h2>
    <div class="mx-auto mt-6 grid max-w-2xl grid-cols-1 gap-4 sm:grid-cols-2">
      {@render children()}
    </div>
  </div>
</div>
