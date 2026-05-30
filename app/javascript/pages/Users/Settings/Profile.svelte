<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import Field from "./components/Field.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { ProfilePageProps } from "./types";
  import { settingsProfile, sessions } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    username_max_length,
    user,
    options,
    profile_url,
    emails,
    errors,
  }: ProfilePageProps = $props();

  const inputClass =
    "w-full rounded-md border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none";
</script>

<svelte:head>
  <title>Profile - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_region"
    title="Region and Timezone"
    description="Use your local region and timezone for accurate dashboards and leaderboards."
  >
    <Form
      id="profile-region-form"
      action={settingsProfile.updateRegion.path()}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
    >
      <Field inputId="country_code" label="Country">
        <Select
          id="country_code"
          name="user[country_code]"
          value={user.country_code || ""}
          items={[
            { value: "", label: "Select a country" },
            ...options.countries,
          ]}
        />
      </Field>

      <Field wrapperId="user_timezone" inputId="timezone" label="Timezone">
        <Select
          id="timezone"
          name="user[timezone]"
          value={user.timezone}
          items={options.timezones}
        />
      </Field>
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-region-form"
        >Save region settings</Button
      >
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_username"
    title="Username"
    description="This username is used in links and public profile pages."
  >
    <Form
      id="profile-username-form"
      action={settingsProfile.updateUsername.path()}
      method="patch"
      class="space-y-3"
      options={{ preserveScroll: true }}
    >
      <Field inputId="username" label="Username" error={errors.username[0]}>
        <input
          id="username"
          name="user[username]"
          value={user.username || ""}
          maxlength={username_max_length}
          placeholder="your-name"
          class={inputClass}
        />
      </Field>
    </Form>

    {#if profile_url}
      <p class="text-sm text-muted mt-2">
        Public profile:
        <a
          href={profile_url}
          target="_blank"
          rel="noopener noreferrer"
          class="text-primary underline"
        >
          {profile_url}
        </a>
      </p>
    {/if}

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-username-form"
        >Save username</Button
      >
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_email_addresses"
    title="Email Addresses"
    description="Add or remove email addresses used for sign-in and verification."
  >
    <div class="space-y-2">
      {#if emails.length > 0}
        {#each emails as email}
          <div
            class="flex flex-wrap items-center gap-2 rounded-md border border-surface-200 bg-darker px-3 py-2"
          >
            <div class="grow text-sm text-surface-content">
              <p>{email.email}</p>
              <p class="text-xs text-muted">{email.source}</p>
            </div>
            {#if email.can_unlink}
              <Form
                action={sessions.unlinkEmail.path()}
                method="delete"
                options={{ preserveScroll: true }}
              >
                <input type="hidden" name="email" value={email.email} />
                <Button
                  type="submit"
                  variant="surface"
                  size="xs"
                  class="rounded-md">Unlink</Button
                >
              </Form>
            {/if}
          </div>
        {/each}
      {:else}
        <p
          class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
        >
          No email addresses are linked.
        </p>
      {/if}
    </div>

    <Form
      id="profile-email-form"
      action={sessions.addEmail.path()}
      method="post"
      class="mt-4 flex flex-col gap-3 sm:flex-row"
      options={{ preserveScroll: true }}
    >
      <input
        type="email"
        name="email"
        required
        placeholder="name@example.com"
        class={`grow ${inputClass}`}
      />
    </Form>

    {#snippet footer()}
      <Button type="submit" class="rounded-md" form="profile-email-form"
        >Add email</Button
      >
    {/snippet}
  </SectionCard>
</SettingsShell>
