<script lang="ts">
  let {
    emoji,
    title = "",
    alt = "",
    class: className = "inline-block w-5 h-5 align-middle",
  }: {
    emoji: string;
    title?: string;
    alt?: string;
    class?: string;
  } = $props();

  const twemojiPath = (emoji: string) => {
    const codePoints = [...emoji]
      .filter((char) => char !== "\uFE0F")
      .map((char) => char.codePointAt(0)!.toString(16))
      .join("-");
    return `https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/${codePoints}.svg`;
  };

  const src = $derived(twemojiPath(emoji));

  const hideBrokenImage = (event: Event) => {
    if (event.currentTarget instanceof HTMLImageElement) {
      event.currentTarget.style.display = "none";
    }
  };
</script>

<img
  {src}
  {title}
  {alt}
  class={className}
  loading="lazy"
  onerror={hideBrokenImage}
/>
