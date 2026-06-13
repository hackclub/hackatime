<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import CheckboxField from "./components/CheckboxField.svelte";
  import Field from "./components/Field.svelte";
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

  let goalsDisabled = $derived(
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
      action={settingsEditors.update.path()}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
    >
      <Field inputId="extension_type" label="Display style">
        <Select
          id="extension_type"
          name="user[hackatime_extension_text_type]"
          bind:value={user.hackatime_extension_text_type}
          items={options.extension_text_types}
        />
      </Field>

      <CheckboxField
        name="user[show_goals_in_statusbar]"
        bind:checked={user.show_goals_in_statusbar}
        disabled={goalsDisabled}
        align="start"
        label="Show daily goal in status bar"
        description={`Appends your daily goal target (e.g. "30m goal") next to your tracked time. Only applies when display style is "Simple text".`}
      />
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="editors-extension-form">
        Save extension settings
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>
