<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { Checkbox } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { EditorsPageProps } from "./types";
  import { settingsEditors } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    user,
    options,
    errors,
  }: EditorsPageProps = $props();

  const settingsUpdatePath = settingsEditors.update.path();

  // When disabled, omit the field from submission entirely so the saved
  // preference is preserved instead of being silently cleared by the
  // hidden "0" fallback input.
  let goals_in_statusbar_disabled = $derived(
    user.hackatime_extension_text_type !== "simple_text",
  );
</script>

<svelte:head>
  <title>Editors - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_hackatime_extension"
    title="Extension Display"
    description="Choose how coding time appears in the extension status text."
  >
    <Form
      id="editors-extension-form"
      action={settingsUpdatePath}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
    >
      <div>
        <label
          for="extension_type"
          class="mb-2 block text-sm text-surface-content"
        >
          Display style
        </label>
        <Select
          id="extension_type"
          name="user[hackatime_extension_text_type]"
          bind:value={user.hackatime_extension_text_type}
          items={options.extension_text_types}
        />
      </div>

      <div>
        <label class="flex items-start gap-3 text-sm text-surface-content">
          {#if !goals_in_statusbar_disabled}
            <input
              type="hidden"
              name="user[show_goals_in_statusbar]"
              value="0"
            />
          {/if}
          <Checkbox.Root
            bind:checked={user.show_goals_in_statusbar}
            name={goals_in_statusbar_disabled
              ? undefined
              : "user[show_goals_in_statusbar]"}
            value="1"
            disabled={goals_in_statusbar_disabled}
            class="mt-0.5 inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[disabled]:opacity-50"
          >
            {#snippet children({ checked })}
              <span class={checked ? "text-[10px]" : "hidden"}>✓</span>
            {/snippet}
          </Checkbox.Root>
          <span class="flex flex-col gap-1">
            <span>Show daily goal in status bar</span>
            <span class="text-xs text-muted">
              Appends your daily goal target (e.g. "30m goal") next to your
              tracked time. Only applies when display style is "Simple text".
            </span>
          </span>
        </label>
      </div>
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="editors-extension-form">
        Save extension settings
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>
