<script lang="ts">
  let {
    countryCode,
    countryName = null,
    class: className = "inline-block w-5 h-5 align-middle",
  }: {
    countryCode?: string | null;
    countryName?: string | null;
    class?: string;
  } = $props();

  const twemojiFlagPath = (code?: string | null) => {
    if (!code) return null;

    const normalizedCode = code.trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(normalizedCode)) return null;

    const unicodeHex = normalizedCode
      .split("")
      .map((char) =>
        (0x1f1e6 + char.charCodeAt(0) - "A".charCodeAt(0)).toString(16),
      )
      .join("-");

    return `https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/${unicodeHex}.svg`;
  };

  const src = $derived(twemojiFlagPath(countryCode));
  const title = $derived(countryName || countryCode || "Country flag");
  const alt = $derived(`${countryCode || ""} flag`.trim());
</script>

{#if src}
  <img {src} {title} {alt} class={className} loading="lazy" />
{/if}
