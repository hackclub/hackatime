<script lang="ts">
  import Link from "./Link.svelte";

  type NavLink = {
    label: string;
    href?: string;
    active?: boolean;
    badge?: number | null;
    action?: string;
    inertia?: boolean;
  };

  let {
    links,
    roleClass,
    navLinkClass,
    onLinkClick,
  }: {
    links: NavLink[];
    roleClass: string;
    navLinkClass: (active?: boolean) => string;
    onLinkClick: () => void;
  } = $props();
</script>

{#each links as link}
  {#if link.inertia}
    <Link
      href={link.href || "#"}
      onclick={onLinkClick}
      class="{navLinkClass(link.active)} {roleClass}"
    >
      {link.label}
      {#if link.badge}
        <span
          class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
        >
          {link.badge}
        </span>
      {/if}
    </Link>
  {:else}
    <a
      href={link.href || "#"}
      onclick={onLinkClick}
      class="{navLinkClass(link.active)} {roleClass}"
    >
      {link.label}
      {#if link.badge}
        <span
          class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
        >
          {link.badge}
        </span>
      {/if}
    </a>
  {/if}
{/each}
