<script module lang="ts">
  import settingsLayout from "./layout";
  export const layout = settingsLayout;
</script>

<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import CheckboxField from "../../../components/CheckboxField.svelte";
  import FormField from "../../../components/FormField.svelte";
  import { settingsEditors } from "../../../api";

  type Props = {
    user: {
      hackatime_extension_text_type: string;
      show_goals_in_statusbar: boolean;
    };
    options: {
      extension_text_types: Array<{ label: string; value: string }>;
    };
  };

  let { user, options }: Props = $props();

  let extensionTextType = $state(user.hackatime_extension_text_type);
  let showGoalsInStatusbar = $state(user.show_goals_in_statusbar);

  $effect(() => {
    extensionTextType = user.hackatime_extension_text_type;
    showGoalsInStatusbar = user.show_goals_in_statusbar;
  });

  let goalsDisabled = $derived(extensionTextType !== "simple_text");
</script>

<svelte:head>
  <title>Editors - Hackatime Settings</title>
</svelte:head>

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
    <FormField inputId="extension_type" label="Display style">
      <Select
        id="extension_type"
        name="user[hackatime_extension_text_type]"
        bind:value={extensionTextType}
        items={options.extension_text_types}
      />
    </FormField>

    <CheckboxField
      name="user[show_goals_in_statusbar]"
      bind:checked={showGoalsInStatusbar}
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
