<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";
  import { Icon } from "svelte-hero-icons";
  import type { LayoutProps } from "../../../types";
  import { SETTINGS_SECTIONS } from "./navigation";

  type Props = {
    layout: LayoutProps;
    active_section: (typeof SETTINGS_SECTIONS)[number]["id"];
    errors: { full_messages: string[] };
    children?: Snippet;
  };

  let { layout, active_section, errors, children }: Props = $props();

  const pillClass = (active: boolean) =>
    `inline-flex min-h-10 shrink-0 items-center gap-1.5 rounded-full px-3 py-2 text-sm font-medium transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${
      active
        ? "bg-surface-100 text-surface-content"
        : "bg-surface/70 text-muted hover:text-surface-content"
    }`;
</script>

<div data-settings-shell>
  <header class="mb-6">
    <h1
      class="text-2xl font-bold tracking-tight text-balance text-surface-content sm:text-3xl"
    >
      Settings for {layout.nav.current_user?.display_name}
    </h1>
  </header>

  {#if errors.full_messages.length > 0}
    <div
      class="mb-6 rounded-lg border border-danger/40 bg-danger/10 px-4 py-3 text-sm text-red"
    >
      <p class="font-semibold">Some changes could not be saved:</p>
      <ul class="mt-2 list-disc pl-5">
        {#each errors.full_messages as message}
          <li>{message}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <nav
    data-settings-mobile-nav
    class="-mx-5 mb-6 overflow-x-auto px-5 lg:hidden"
  >
    <div class="flex min-w-full gap-2 pb-1">
      {#each SETTINGS_SECTIONS as section}
        {@const active = active_section === section.id}
        <Link
          href={section.path}
          data-settings-mobile-nav-item
          data-active={active}
          class={pillClass(active)}
        >
          <Icon
            src={section.icon}
            solid={active}
            size="16"
            class={`shrink-0 ${active ? "text-primary" : ""}`}
          />
          {section.label}
        </Link>
      {/each}
    </div>
  </nav>

  <div
    class="grid grid-cols-1 gap-6 lg:grid-cols-[280px_minmax(0,1fr)] lg:gap-8"
  >
    <aside class="hidden h-max lg:sticky lg:top-8 lg:block">
      <div data-settings-sidebar class="rounded-[1.25rem] bg-surface/90 p-1">
        {#each SETTINGS_SECTIONS as section}
          {@const active = active_section === section.id}
          <Link
            href={section.path}
            class={`group flex min-h-10 w-full items-center gap-2.5 rounded-2xl px-3 py-2.5 text-left transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${
              active
                ? "bg-surface-100 text-surface-content shadow-[0_8px_20px_rgba(0,0,0,0.12),inset_0_1px_0_rgba(255,255,255,0.08)]"
                : "bg-transparent text-muted hover:bg-surface-100/60 hover:text-surface-content hover:shadow-[0_1px_0_rgba(255,255,255,0.05)]"
            }`}
          >
            <Icon
              src={section.icon}
              solid={active}
              size="18"
              class={`shrink-0 transition-colors duration-150 ${
                active
                  ? "text-primary"
                  : "text-muted group-hover:text-surface-content"
              }`}
            />
            <p class="text-sm font-semibold">{section.label}</p>
          </Link>
        {/each}
      </div>
    </aside>

    <div data-settings-content class="min-w-0 space-y-5">
      {@render children?.()}
    </div>
  </div>
</div>
