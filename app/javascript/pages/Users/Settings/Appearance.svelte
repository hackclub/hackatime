<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { RadioGroup } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { AppearancePageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    theme_update_path,
    user,
    options,
    errors,
  }: AppearancePageProps = $props();

  let selectedTheme = $state("rose");

  $effect(() => {
    selectedTheme = user.theme || "rose";
  });

  const applySelectedTheme = () => {
    if (typeof document === "undefined") return;

    const theme = options.themes.find(
      (option) => option.value === selectedTheme,
    );
    if (!theme) return;

    document.documentElement.dataset.theme = theme.value;
    document.documentElement.dataset.colorScheme = theme.color_scheme;

    document
      .querySelector('meta[name="color-scheme"]')
      ?.setAttribute("content", theme.color_scheme);
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute("content", theme.theme_color);
  };
</script>

<svelte:head>
  <title>Appearance - Hackatime Settings</title>
</svelte:head>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
>
  <SectionCard
    id="user_theme"
    title="Theme"
    description="Pick how Hackatime looks for your account."
    wide
  >
    <Form
      id="appearance-theme-form"
      action={theme_update_path}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
      onSuccess={applySelectedTheme}
    >
      <RadioGroup.Root
        name="user[theme]"
        bind:value={selectedTheme}
        class="grid grid-cols-1 gap-4 md:grid-cols-2"
      >
        {#each options.themes as theme}
          <RadioGroup.Item
            value={theme.value}
            class="block cursor-pointer rounded-xl border p-4 text-left outline-none transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-surface-100 data-[state=unchecked]:border-surface-200 data-[state=unchecked]:bg-darker/40 data-[state=unchecked]:hover:border-surface-300"
          >
            {#snippet children({ checked })}
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-surface-content">
                    {theme.label}
                  </p>
                  <p class="mt-1 text-xs text-muted">{theme.description}</p>
                </div>
                {#if checked}
                  <span
                    class="rounded-full bg-primary/20 px-2 py-0.5 text-xs font-medium text-primary"
                  >
                    Selected
                  </span>
                {/if}
              </div>

              <div
                class="mt-3 rounded-lg border p-2"
                style={`background:${theme.preview.darker};border-color:${theme.preview.darkless};color:${theme.preview.content};`}
              >
                <div
                  class="flex items-center justify-between rounded-md px-2 py-1"
                  style={`background:${theme.preview.dark};`}
                >
                  <span class="text-[11px] font-semibold">Dashboard</span>
                  <span class="text-[10px] opacity-80">2h 14m</span>
                </div>

                <div class="mt-2 grid grid-cols-[1fr_auto] items-center gap-2">
                  <span
                    class="h-2 rounded"
                    style={`background:${theme.preview.primary};`}
                  ></span>
                  <span
                    class="h-2 w-8 rounded"
                    style={`background:${theme.preview.darkless};`}
                  ></span>
                </div>

                <div class="mt-2 flex gap-1.5">
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.info};`}
                  ></span>
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.success};`}
                  ></span>
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.warning};`}
                  ></span>
                </div>
              </div>
            {/snippet}
          </RadioGroup.Item>
        {/each}
      </RadioGroup.Root>
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="appearance-theme-form">
        Save theme
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>
