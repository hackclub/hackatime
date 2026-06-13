<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { Icon, ArrowPath, Trash } from "svelte-hero-icons";
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
    display_name_max_length,
    user,
    options,
    profile_url,
    emails,
    errors,
  }: ProfilePageProps = $props();

  const inputClass =
    "w-full rounded-md border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none";

  function formatCooldown(seconds: number): string {
    if (seconds <= 0) return "";

    const minutes = Math.ceil(seconds / 60);
    return `Resend in ${minutes}m`;
  }
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
    id="user_display_name"
    title="Display Name"
    description="This name appears across Hackatime instead of your Slack, GitHub, or username."
  >
    <Form
      id="profile-display-name-form"
      action={settingsProfile.updateDisplayName.path()}
      method="patch"
      class="space-y-3"
      options={{ preserveScroll: true }}
    >
      <Field
        inputId="display_name_override"
        label="Display name"
        error={errors.display_name_override[0]}
      >
        <input
          id="display_name_override"
          name="user[display_name_override]"
          value={user.display_name_override || ""}
          maxlength={display_name_max_length}
          placeholder={user.display_name}
          class={inputClass}
        />
      </Field>
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-display-name-form"
        >Save display name</Button
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
              <p class="flex items-center gap-2">
                <span>{email.email}</span>
                {#if email.pending}
                  <span
                    class="rounded-md border border-surface-200 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted"
                  >
                    Unverified
                  </span>
                  {#if email.expired}
                    <span
                      class="rounded-md border border-surface-200 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted"
                    >
                      Expired
                    </span>
                  {/if}
                {/if}
              </p>
              <p class="text-xs text-muted">{email.source}</p>
            </div>
            {#if email.pending}
              <Form
                action={sessions.resendEmailVerification.path()}
                method="post"
                options={{ preserveScroll: true }}
              >
                <input type="hidden" name="email" value={email.email} />
                <Button
                  type="submit"
                  unstyled
                  disabled={!email.can_resend}
                  title={email.can_resend
                    ? "Resend verification email"
                    : formatCooldown(email.resend_cooldown_seconds) ||
                      "Resend available soon"}
                  aria-label="Resend verification email"
                  class="inline-flex items-center justify-center rounded-md p-1.5 text-muted transition-colors hover:text-surface-content disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <Icon src={ArrowPath} size="20" />
                </Button>
              </Form>
            {/if}
            {#if email.can_unlink}
              <Form
                action={sessions.unlinkEmail.path()}
                method="delete"
                options={{ preserveScroll: true }}
              >
                <input type="hidden" name="email" value={email.email} />
                <Button
                  type="submit"
                  unstyled
                  title={email.pending ? "Remove email" : "Unlink email"}
                  aria-label={email.pending ? "Remove email" : "Unlink email"}
                  class="inline-flex items-center justify-center rounded-md p-1.5 text-muted transition-colors hover:text-red"
                >
                  <Icon src={Trash} size="20" />
                </Button>
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
