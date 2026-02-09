<script lang="ts">
  type NavUserMention = {
    display_name: string;
    avatar_url?: string | null;
    title?: string | null;
    country_code?: string | null;
    country_name?: string | null;
  };

  let { user }: { user: NavUserMention } = $props();

  const countryFlagUrl = (countryCode?: string | null) => {
    if (!countryCode) return null;
    const upper = countryCode.toUpperCase();
    if (upper.length !== 2) return null;
    const codepoints = Array.from(upper).map(
      (char) => 0x1f1e6 + char.charCodeAt(0) - "A".charCodeAt(0),
    );
    const hex = codepoints.map((codepoint) => codepoint.toString(16)).join("-");
    return `https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/${hex}.svg`;
  };
</script>

<div class="user-info flex items-center gap-2" title={user.title || undefined}>
  {#if user.avatar_url}
    <img
      src={user.avatar_url}
      alt={`${user.display_name}'s avatar`}
      class="rounded-full aspect-square border border-gray-300"
      width="32"
      height="32"
      loading="lazy"
    />
  {/if}
  <span class="inline-flex items-center gap-1">
    {user.display_name}
  </span>
  {#if user.country_code}
    <span title={user.country_name || undefined} class="flex items-center">
      <img
        src={countryFlagUrl(user.country_code)}
        alt={`${user.country_code} flag`}
        class="inline-block w-5 h-5 align-middle"
        loading="lazy"
      />
    </span>
  {/if}
</div>
