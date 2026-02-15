<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import { onMount } from "svelte";

  type SectionId =
    | "profile"
    | "integrations"
    | "access"
    | "badges"
    | "data"
    | "admin";

  type SectionPaths = Record<SectionId, string>;

  type Option = {
    label: string;
    value: string;
  };

  type UserProps = {
    id: number;
    display_name: string;
    timezone: string;
    country_code?: string | null;
    username?: string | null;
    uses_slack_status: boolean;
    hackatime_extension_text_type: string;
    allow_public_stats_lookup: boolean;
    trust_level: string;
    can_request_deletion: boolean;
    github_uid?: string | null;
    github_username?: string | null;
    slack_uid?: string | null;
  };

  type PathsProps = {
    settings_path: string;
    wakatime_setup_path: string;
    slack_auth_path: string;
    github_auth_path: string;
    github_unlink_path: string;
    add_email_path: string;
    unlink_email_path: string;
    rotate_api_key_path: string;
    migrate_heartbeats_path: string;
    export_all_heartbeats_path: string;
    export_range_heartbeats_path: string;
    import_heartbeats_path: string;
    create_deletion_path: string;
    user_wakatime_mirrors_path: string;
  };

  type OptionsProps = {
    countries: Option[];
    timezones: Option[];
    extension_text_types: Option[];
    badge_themes: string[];
  };

  type SlackProps = {
    can_enable_status: boolean;
    notification_channels: {
      id: string;
      label: string;
      url: string;
    }[];
  };

  type GithubProps = {
    connected: boolean;
    username?: string | null;
    profile_url?: string | null;
  };

  type EmailProps = {
    email: string;
    source: string;
    can_unlink: boolean;
  };

  type BadgesProps = {
    general_badge_url: string;
    project_badge_url?: string | null;
    project_badge_base_url?: string | null;
    projects: string[];
    profile_url?: string | null;
    markscribe_template: string;
    markscribe_reference_url: string;
    markscribe_preview_image_url: string;
  };

  type ConfigFileProps = {
    content?: string | null;
    has_api_key: boolean;
    empty_message: string;
    api_key?: string | null;
    api_url: string;
  };

  type MigrationProps = {
    jobs: { id: string; status: string }[];
  };

  type DataExportProps = {
    total_heartbeats: string;
    total_coding_time: string;
    heartbeats_last_7_days: string;
    is_restricted: boolean;
  };

  type AdminToolsProps = {
    visible: boolean;
    mirrors: {
      id: number;
      endpoint_url: string;
      last_synced_ago: string;
      destroy_path: string;
    }[];
  };

  type UiProps = {
    show_dev_import: boolean;
  };

  type ErrorsProps = {
    full_messages: string[];
    username: string[];
  };

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    settings_update_path,
    username_max_length,
    user,
    paths,
    options,
    slack,
    github,
    emails,
    badges,
    config_file,
    migration,
    data_export,
    admin_tools,
    ui,
    errors,
  }: {
    active_section: SectionId;
    section_paths: SectionPaths;
    page_title: string;
    heading: string;
    subheading: string;
    settings_update_path: string;
    username_max_length: number;
    user: UserProps;
    paths: PathsProps;
    options: OptionsProps;
    slack: SlackProps;
    github: GithubProps;
    emails: EmailProps[];
    badges: BadgesProps;
    config_file: ConfigFileProps;
    migration: MigrationProps;
    data_export: DataExportProps;
    admin_tools: AdminToolsProps;
    ui: UiProps;
    errors: ErrorsProps;
  } = $props();

  const defaultTheme = (themes: string[]) =>
    themes.includes("darcula") ? "darcula" : themes[0] || "default";

  const sections = $derived.by<
    { id: SectionId; label: string; blurb: string; path: string }[]
  >(() => {
    const list = [
      {
        id: "profile" as SectionId,
        label: "Profile",
        blurb: "Username, region, timezone, theming, and privacy.",
        path: section_paths.profile,
      },
      {
        id: "integrations" as SectionId,
        label: "Integrations",
        blurb: "Slack status, GitHub link, and email sign-in addresses.",
        path: section_paths.integrations,
      },
      {
        id: "access" as SectionId,
        label: "Access",
        blurb: "Time tracking setup, extension options, and API key access.",
        path: section_paths.access,
      },
      {
        id: "badges" as SectionId,
        label: "Badges",
        blurb: "Shareable badges and profile snippets.",
        path: section_paths.badges,
      },
      {
        id: "data" as SectionId,
        label: "Data",
        blurb: "Exports, migration jobs, and account deletion controls.",
        path: section_paths.data,
      },
    ];

    if (admin_tools.visible) {
      list.push({
        id: "admin",
        label: "Admin",
        blurb: "WakaTime mirror endpoints.",
        path: section_paths.admin,
      });
    }

    return list;
  });

  const knownSectionIds = $derived(new Set(sections.map((section) => section.id)));
  const hashSectionMap: Record<string, SectionId> = {
    user_region: "profile",
    user_timezone: "profile",
    user_username: "profile",
    user_privacy: "profile",
    user_hackatime_extension: "access",
    user_api_key: "access",
    user_config_file: "access",
    user_slack_status: "integrations",
    user_slack_notifications: "integrations",
    user_github_account: "integrations",
    user_email_addresses: "integrations",
    user_stats_badges: "badges",
    user_markscribe: "badges",
    user_migration_assistant: "data",
    download_user_data: "data",
    delete_account: "data",
    wakatime_mirror: "admin",
  };

  let activeSection = $state<SectionId>("profile");
  let csrfToken = $state("");
  let selectedTheme = $state("default");
  let selectedProject = $state("");
  let rotatingApiKey = $state(false);
  let rotatedApiKey = $state("");
  let rotatedApiKeyError = $state("");
  let apiKeyCopied = $state(false);

  $effect(() => {
    if (activeSection !== active_section) {
      activeSection = active_section;
    }
  });

  $effect(() => {
    if (options.badge_themes.length > 0 && !options.badge_themes.includes(selectedTheme)) {
      selectedTheme = defaultTheme(options.badge_themes);
    }
  });

  $effect(() => {
    if (badges.projects.length === 0) {
      selectedProject = "";
      return;
    }

    if (!badges.projects.includes(selectedProject)) {
      selectedProject = badges.projects[0];
    }
  });

  const sectionButtonClass = (sectionId: SectionId) =>
    `w-full rounded-lg border px-3 py-3 text-left transition-colors ${activeSection === sectionId ? "border-primary bg-surface-100 text-surface-content" : "border-surface-200 bg-surface hover:border-surface-300 text-muted hover:text-surface-content"}`;

  const badgeUrl = () => {
    const url = new URL(badges.general_badge_url);
    url.searchParams.set("theme", selectedTheme);
    return url.toString();
  };

  const projectBadgeUrl = () => {
    if (!badges.project_badge_base_url || !selectedProject) return "";
    return `${badges.project_badge_base_url}${encodeURIComponent(selectedProject)}`;
  };

  const sectionFromHash = (hash: string): SectionId | null => {
    const cleanHash = hash.replace(/^#/, "");
    return hashSectionMap[cleanHash] || null;
  };

  const rotateApiKey = async () => {
    if (rotatingApiKey || typeof window === "undefined") return;

    const confirmed = window.confirm(
      "Rotate your API key now? This immediately invalidates the current key.",
    );
    if (!confirmed) return;

    rotatingApiKey = true;
    rotatedApiKey = "";
    rotatedApiKeyError = "";
    apiKeyCopied = false;

    try {
      const response = await fetch(paths.rotate_api_key_path, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
      });

      const body = await response.json();
      if (!response.ok || !body.token) {
        throw new Error(body.error || "Unable to rotate API key.");
      }

      rotatedApiKey = body.token;
    } catch (error) {
      rotatedApiKeyError =
        error instanceof Error ? error.message : "Unable to rotate API key.";
    } finally {
      rotatingApiKey = false;
    }
  };

  const copyApiKey = async () => {
    if (!rotatedApiKey || typeof navigator === "undefined") return;
    await navigator.clipboard.writeText(rotatedApiKey);
    apiKeyCopied = true;
  };

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";

    const syncSectionFromHash = () => {
      const section = sectionFromHash(window.location.hash);
      if (!section || !knownSectionIds.has(section)) return;

      if (section !== activeSection && section_paths[section]) {
        window.location.replace(`${section_paths[section]}${window.location.hash}`);
        return;
      }

      activeSection = section;
    };

    syncSectionFromHash();
    window.addEventListener("hashchange", syncSectionFromHash);
    return () => window.removeEventListener("hashchange", syncSectionFromHash);
  });
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <header class="mb-8">
    <h1 class="text-3xl font-bold text-surface-content">{heading}</h1>
    <p class="mt-2 text-sm text-muted">{subheading}</p>
  </header>

  {#if errors.full_messages.length > 0}
    <div class="mb-6 rounded-lg border border-danger/40 bg-danger/10 px-4 py-3 text-sm text-red-200">
      <p class="font-semibold">Some changes could not be saved:</p>
      <ul class="mt-2 list-disc pl-5">
        {#each errors.full_messages as message}
          <li>{message}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <div class="grid grid-cols-1 gap-6 lg:grid-cols-[260px_minmax(0,1fr)]">
    <aside class="rounded-xl border border-surface-200 bg-surface p-4 h-max lg:sticky lg:top-8">
      <h2 class="mb-3 text-xs font-semibold uppercase tracking-wide text-muted">
        Sections
      </h2>
      <div class="space-y-2">
        {#each sections as section}
          <Link href={section.path} class={`block ${sectionButtonClass(section.id)}`}>
            <p class="text-sm font-semibold">{section.label}</p>
            <p class="mt-1 text-xs opacity-80">{section.blurb}</p>
          </Link>
        {/each}
      </div>
    </aside>

    <section class="rounded-xl border border-surface-200 bg-surface p-5 md:p-6">
      {#if activeSection === "profile"}
        <div class="space-y-8">
          <section id="user_region">
            <h2 class="text-xl font-semibold text-surface-content">Region and Timezone</h2>
            <p class="mt-1 text-sm text-muted">
              Use your local region and timezone for accurate dashboards and
              leaderboards.
            </p>
            <form method="post" action={settings_update_path} class="mt-4 space-y-4">
              <input type="hidden" name="_method" value="patch" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />

              <div>
                <label for="country_code" class="mb-2 block text-sm text-surface-content">
                  Country
                </label>
                <select
                  id="country_code"
                  name="user[country_code]"
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                  value={user.country_code || ""}
                >
                  <option value="">Select a country</option>
                  {#each options.countries as country}
                    <option value={country.value}>{country.label}</option>
                  {/each}
                </select>
              </div>

              <div id="user_timezone">
                <label for="timezone" class="mb-2 block text-sm text-surface-content">
                  Timezone
                </label>
                <select
                  id="timezone"
                  name="user[timezone]"
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                  value={user.timezone}
                >
                  {#each options.timezones as timezone}
                    <option value={timezone.value}>{timezone.label}</option>
                  {/each}
                </select>
              </div>

              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Save region settings
              </Button>
            </form>
          </section>

          <section id="user_username">
            <h2 class="text-xl font-semibold text-surface-content">Username</h2>
            <p class="mt-1 text-sm text-muted">
              This username is used in links and public profile pages.
            </p>
            <form method="post" action={settings_update_path} class="mt-4 space-y-3">
              <input type="hidden" name="_method" value="patch" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />

              <div>
                <label for="username" class="mb-2 block text-sm text-surface-content">
                  Username
                </label>
                <input
                  id="username"
                  name="user[username]"
                  value={user.username || ""}
                  maxlength={username_max_length}
                  placeholder="your-name"
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                />
                {#if errors.username.length > 0}
                  <p class="mt-2 text-xs text-red-300">{errors.username[0]}</p>
                {/if}
              </div>

              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Save username
              </Button>
            </form>

            {#if badges.profile_url}
              <p class="mt-3 text-sm text-muted">
                Public profile:
                <a
                  href={badges.profile_url}
                  target="_blank"
                  class="text-primary underline"
                >
                  {badges.profile_url}
                </a>
              </p>
            {/if}
          </section>

          <section id="user_privacy">
            <h2 class="text-xl font-semibold text-surface-content">Privacy</h2>
            <p class="mt-1 text-sm text-muted">
              Control whether your coding stats can be used by public APIs.
            </p>
            <form method="post" action={settings_update_path} class="mt-4 space-y-3">
              <input type="hidden" name="_method" value="patch" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />

              <label class="flex items-center gap-3 text-sm text-surface-content">
                <input type="hidden" name="user[allow_public_stats_lookup]" value="0" />
                <input
                  type="checkbox"
                  name="user[allow_public_stats_lookup]"
                  value="1"
                  checked={user.allow_public_stats_lookup}
                  class="h-4 w-4 rounded border-surface-200 bg-darker text-primary"
                />
                Allow public stats lookup
              </label>

              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Save privacy settings
              </Button>
            </form>
          </section>
        </div>
      {/if}

      {#if activeSection === "integrations"}
        <div class="space-y-8">
          <section id="user_slack_status">
            <h2 class="text-xl font-semibold text-surface-content">Slack Status Sync</h2>
            <p class="mt-1 text-sm text-muted">
              Keep your Slack status updated while you are actively coding.
            </p>

            {#if !slack.can_enable_status}
              <Link
                href={paths.slack_auth_path}
                class="mt-4 inline-flex rounded-md border border-surface-200 bg-surface-100 px-3 py-2 text-sm text-surface-content transition-colors hover:bg-surface-200"
              >
                Re-authorize with Slack
              </Link>
            {/if}

            <form method="post" action={settings_update_path} class="mt-4 space-y-3">
              <input type="hidden" name="_method" value="patch" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />

              <label class="flex items-center gap-3 text-sm text-surface-content">
                <input type="hidden" name="user[uses_slack_status]" value="0" />
                <input
                  type="checkbox"
                  name="user[uses_slack_status]"
                  value="1"
                  checked={user.uses_slack_status}
                  class="h-4 w-4 rounded border-surface-200 bg-darker text-primary"
                />
                Update my Slack status automatically
              </label>

              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Save Slack settings
              </Button>
            </form>
          </section>

          <section id="user_slack_notifications">
            <h2 class="text-xl font-semibold text-surface-content">Slack Channel Notifications</h2>
            <p class="mt-1 text-sm text-muted">
              Enable notifications in any channel by running
              <code class="rounded bg-darker px-1 py-0.5 text-xs text-surface-content">
                /sailorslog on
              </code>
              in that channel.
            </p>

            {#if slack.notification_channels.length > 0}
              <ul class="mt-4 space-y-2">
                {#each slack.notification_channels as channel}
                  <li class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content">
                    <a href={channel.url} target="_blank" class="underline">{channel.label}</a>
                  </li>
                {/each}
              </ul>
            {:else}
              <p class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
                No channel notifications are enabled.
              </p>
            {/if}
          </section>

          <section id="user_github_account">
            <h2 class="text-xl font-semibold text-surface-content">Connected GitHub Account</h2>
            <p class="mt-1 text-sm text-muted">
              Connect GitHub to show project links in dashboards and leaderboards.
            </p>

            {#if github.connected && github.username}
              <div class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-3 text-sm text-surface-content">
                Connected as
                <a href={github.profile_url || "#"} target="_blank" class="underline">
                  @{github.username}
                </a>
              </div>
              <div class="mt-3 flex flex-wrap gap-3">
                <Link
                  href={paths.github_auth_path}
                  class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
                >
                  Reconnect GitHub
                </Link>
                <form
                  method="post"
                  action={paths.github_unlink_path}
                  onsubmit={(event) => {
                    if (
                      !window.confirm(
                        "Unlink this GitHub account? GitHub-based features will stop until relinked.",
                      )
                    ) {
                      event.preventDefault();
                    }
                  }}
                >
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="authenticity_token" value={csrfToken} />
                  <Button unstyled
                    type="submit"
                    class="rounded-md border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
                  >
                    Unlink GitHub
                  </Button>
                </form>
              </div>
            {:else}
              <Link
                href={paths.github_auth_path}
                class="mt-4 inline-flex rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Connect GitHub
              </Link>
            {/if}
          </section>

          <section id="user_email_addresses">
            <h2 class="text-xl font-semibold text-surface-content">Email Addresses</h2>
            <p class="mt-1 text-sm text-muted">
              Add or remove email addresses used for sign-in and verification.
            </p>

            <div class="mt-4 space-y-2">
              {#if emails.length > 0}
                {#each emails as email}
                  <div class="flex flex-wrap items-center gap-2 rounded-md border border-surface-200 bg-darker px-3 py-2">
                    <div class="grow text-sm text-surface-content">
                      <p>{email.email}</p>
                      <p class="text-xs text-muted">{email.source}</p>
                    </div>
                    {#if email.can_unlink}
                      <form method="post" action={paths.unlink_email_path}>
                        <input type="hidden" name="_method" value="delete" />
                        <input type="hidden" name="authenticity_token" value={csrfToken} />
                        <input type="hidden" name="email" value={email.email} />
                        <Button unstyled
                          type="submit"
                          class="rounded-md border border-surface-200 bg-surface-100 px-3 py-1.5 text-xs font-semibold text-surface-content transition-colors hover:bg-surface-200"
                        >
                          Unlink
                        </Button>
                      </form>
                    {/if}
                  </div>
                {/each}
              {:else}
                <p class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
                  No email addresses are linked.
                </p>
              {/if}
            </div>

            <form method="post" action={paths.add_email_path} class="mt-4 flex flex-col gap-3 sm:flex-row">
              <input type="hidden" name="authenticity_token" value={csrfToken} />
              <input
                type="email"
                name="email"
                required
                placeholder="name@example.com"
                class="grow rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
              />
              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Add email
              </Button>
            </form>
          </section>
        </div>
      {/if}

      {#if activeSection === "access"}
        <div class="space-y-8">
          <section>
            <h2 class="text-xl font-semibold text-surface-content">Time Tracking Setup</h2>
            <p class="mt-1 text-sm text-muted">
              Use the setup guide if you are configuring a new editor or device.
            </p>
            <Link
              href={paths.wakatime_setup_path}
              class="mt-4 inline-flex rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
            >
              Open setup guide
            </Link>
          </section>

          <section id="user_hackatime_extension">
            <h2 class="text-xl font-semibold text-surface-content">Extension Display</h2>
            <p class="mt-1 text-sm text-muted">
              Choose how coding time appears in the extension status text.
            </p>
            <form method="post" action={settings_update_path} class="mt-4 space-y-4">
              <input type="hidden" name="_method" value="patch" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />

              <div>
                <label for="extension_type" class="mb-2 block text-sm text-surface-content">
                  Display style
                </label>
                <select
                  id="extension_type"
                  name="user[hackatime_extension_text_type]"
                  value={user.hackatime_extension_text_type}
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                >
                  {#each options.extension_text_types as textType}
                    <option value={textType.value}>{textType.label}</option>
                  {/each}
                </select>
              </div>

              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Save extension settings
              </Button>
            </form>
          </section>

          <section id="user_api_key">
            <h2 class="text-xl font-semibold text-surface-content">API Key</h2>
            <p class="mt-1 text-sm text-muted">
              Rotate your API key if you think it has been exposed.
            </p>
            <Button unstyled
              type="button"
              class="mt-4 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
              onclick={rotateApiKey}
              disabled={rotatingApiKey}
            >
              {rotatingApiKey ? "Rotating..." : "Rotate API key"}
            </Button>

            {#if rotatedApiKeyError}
              <p class="mt-3 rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200">
                {rotatedApiKeyError}
              </p>
            {/if}

            {#if rotatedApiKey}
              <div class="mt-4 rounded-md border border-surface-200 bg-darker p-3">
                <p class="text-xs font-semibold uppercase tracking-wide text-muted">
                  New API key
                </p>
                <code class="mt-2 block break-all text-sm text-surface-content">{rotatedApiKey}</code>
                <Button unstyled
                  type="button"
                  class="mt-3 rounded-md border border-surface-200 bg-surface-100 px-3 py-1.5 text-xs font-semibold text-surface-content transition-colors hover:bg-surface-200"
                  onclick={copyApiKey}
                >
                  {apiKeyCopied ? "Copied" : "Copy key"}
                </Button>
              </div>
            {/if}
          </section>

          <section id="user_config_file">
            <h2 class="text-xl font-semibold text-surface-content">WakaTime Config File</h2>
            <p class="mt-1 text-sm text-muted">
              Copy this into your <code class="rounded bg-darker px-1 py-0.5 text-xs">~/.wakatime.cfg</code> file.
            </p>

            {#if config_file.has_api_key && config_file.content}
              <pre class="mt-4 overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 text-xs text-surface-content">{config_file.content}</pre>
            {:else}
              <p class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
                {config_file.empty_message}
              </p>
            {/if}
          </section>
        </div>
      {/if}

      {#if activeSection === "badges"}
        <div class="space-y-8">
          <section id="user_stats_badges">
            <h2 class="text-xl font-semibold text-surface-content">Stats Badges</h2>
            <p class="mt-1 text-sm text-muted">
              Generate links for profile badges that display your coding stats.
            </p>

            <div class="mt-4 space-y-4">
              <div>
                <label for="badge_theme" class="mb-2 block text-sm text-surface-content">
                  Theme
                </label>
                <select
                  id="badge_theme"
                  bind:value={selectedTheme}
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                >
                  {#each options.badge_themes as theme}
                    <option value={theme}>{theme}</option>
                  {/each}
                </select>
              </div>

              <div class="rounded-md border border-surface-200 bg-darker p-4">
                <img src={badgeUrl()} alt="General coding stats badge preview" class="max-w-full rounded" />
                <pre class="mt-3 overflow-x-auto text-xs text-surface-content">{badgeUrl()}</pre>
              </div>
            </div>

            {#if badges.projects.length > 0 && badges.project_badge_base_url}
              <div class="mt-6 border-t border-surface-200 pt-6">
                <label for="badge_project" class="mb-2 block text-sm text-surface-content">
                  Project
                </label>
                <select
                  id="badge_project"
                  bind:value={selectedProject}
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                >
                  {#each badges.projects as project}
                    <option value={project}>{project}</option>
                  {/each}
                </select>
                <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4">
                  <img
                    src={projectBadgeUrl()}
                    alt="Project stats badge preview"
                    class="max-w-full rounded"
                  />
                  <pre class="mt-3 overflow-x-auto text-xs text-surface-content">{projectBadgeUrl()}</pre>
                </div>
              </div>
            {/if}
          </section>

          <section id="user_markscribe">
            <h2 class="text-xl font-semibold text-surface-content">Markscribe Template</h2>
            <p class="mt-1 text-sm text-muted">
              Use this snippet with markscribe to include your coding stats in a
              README.
            </p>
            <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4">
              <pre class="overflow-x-auto text-sm text-surface-content">{badges.markscribe_template}</pre>
            </div>
            <p class="mt-3 text-sm text-muted">
              Reference:
              <a
                href={badges.markscribe_reference_url}
                target="_blank"
                class="text-primary underline"
              >
                markscribe template docs
              </a>
            </p>
            <img
              src={badges.markscribe_preview_image_url}
              alt="Example markscribe output"
              class="mt-4 w-full max-w-3xl rounded-md border border-surface-200"
            />
          </section>
        </div>
      {/if}

      {#if activeSection === "data"}
        <div class="space-y-8">
          <section id="user_migration_assistant">
            <h2 class="text-xl font-semibold text-surface-content">Migration Assistant</h2>
            <p class="mt-1 text-sm text-muted">
              Queue migration of heartbeats and API keys from legacy Hackatime.
            </p>
            <form method="post" action={paths.migrate_heartbeats_path} class="mt-4">
              <input type="hidden" name="authenticity_token" value={csrfToken} />
              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Start migration
              </Button>
            </form>

            {#if migration.jobs.length > 0}
              <div class="mt-4 space-y-2">
                {#each migration.jobs as job}
                  <div class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content">
                    Job {job.id}: {job.status}
                  </div>
                {/each}
              </div>
            {/if}
          </section>

          <section id="download_user_data">
            <h2 class="text-xl font-semibold text-surface-content">Download Data</h2>

            {#if data_export.is_restricted}
              <p class="mt-3 rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200">
                Data export is currently restricted for this account.
              </p>
            {:else}
              <p class="mt-1 text-sm text-muted">
                Download your coding history as JSON for backups or analysis.
              </p>

              <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
                  <p class="text-xs uppercase tracking-wide text-muted">Total heartbeats</p>
                  <p class="mt-1 text-lg font-semibold text-surface-content">
                    {data_export.total_heartbeats}
                  </p>
                </div>
                <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
                  <p class="text-xs uppercase tracking-wide text-muted">Total coding time</p>
                  <p class="mt-1 text-lg font-semibold text-surface-content">
                    {data_export.total_coding_time}
                  </p>
                </div>
                <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
                  <p class="text-xs uppercase tracking-wide text-muted">Last 7 days</p>
                  <p class="mt-1 text-lg font-semibold text-surface-content">
                    {data_export.heartbeats_last_7_days}
                  </p>
                </div>
              </div>

              <div class="mt-4 space-y-3">
                <a
                  href={paths.export_all_heartbeats_path}
                  class="inline-flex rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
                >
                  Export all heartbeats
                </a>

                <form
                  method="get"
                  action={paths.export_range_heartbeats_path}
                  class="grid grid-cols-1 gap-3 rounded-md border border-surface-200 bg-darker p-4 sm:grid-cols-3"
                >
                  <input
                    type="date"
                    name="start_date"
                    required
                    class="rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                  />
                  <input
                    type="date"
                    name="end_date"
                    required
                    class="rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                  />
                  <Button unstyled
                    type="submit"
                    class="rounded-md border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
                  >
                    Export date range
                  </Button>
                </form>
              </div>

              {#if ui.show_dev_import}
                <form
                  method="post"
                  action={paths.import_heartbeats_path}
                  enctype="multipart/form-data"
                  class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
                >
                  <input type="hidden" name="authenticity_token" value={csrfToken} />
                  <label class="mb-2 block text-sm text-surface-content" for="heartbeat_file">
                    Import heartbeats (development only)
                  </label>
                  <input
                    id="heartbeat_file"
                    type="file"
                    name="heartbeat_file"
                    accept=".json,application/json"
                    required
                    class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content"
                  />
                  <Button unstyled
                    type="submit"
                    class="mt-3 rounded-md border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
                  >
                    Import file
                  </Button>
                </form>
              {/if}
            {/if}
          </section>

          <section id="delete_account">
            <h2 class="text-xl font-semibold text-surface-content">Account Deletion</h2>
            {#if user.can_request_deletion}
              <p class="mt-1 text-sm text-muted">
                Request permanent deletion. The account enters a waiting period
                before final removal.
              </p>
              <form
                method="post"
                action={paths.create_deletion_path}
                class="mt-4"
                onsubmit={(event) => {
                  if (
                    !window.confirm(
                      "Submit account deletion request? This action starts the deletion process.",
                    )
                  ) {
                    event.preventDefault();
                  }
                }}
              >
                <input type="hidden" name="authenticity_token" value={csrfToken} />
                <Button unstyled
                  type="submit"
                  class="rounded-md border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
                >
                  Request deletion
                </Button>
              </form>
            {:else}
              <p class="mt-3 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
                Deletion request is unavailable for this account right now.
              </p>
            {/if}
          </section>
        </div>
      {/if}

      {#if activeSection === "admin" && admin_tools.visible}
        <div class="space-y-8">
          <section id="wakatime_mirror">
            <h2 class="text-xl font-semibold text-surface-content">WakaTime Mirrors</h2>
            <p class="mt-1 text-sm text-muted">
              Mirror heartbeats to external WakaTime-compatible endpoints.
            </p>

            {#if admin_tools.mirrors.length > 0}
              <div class="mt-4 space-y-2">
                {#each admin_tools.mirrors as mirror}
                  <div class="rounded-md border border-surface-200 bg-darker p-3">
                    <p class="text-sm font-semibold text-surface-content">
                      {mirror.endpoint_url}
                    </p>
                    <p class="mt-1 text-xs text-muted">Last synced: {mirror.last_synced_ago}</p>
                    <form
                      method="post"
                      action={mirror.destroy_path}
                      class="mt-3"
                      onsubmit={(event) => {
                        if (!window.confirm("Delete this mirror endpoint?")) {
                          event.preventDefault();
                        }
                      }}
                    >
                      <input type="hidden" name="_method" value="delete" />
                      <input type="hidden" name="authenticity_token" value={csrfToken} />
                      <Button unstyled
                        type="submit"
                        class="rounded-md border border-surface-200 bg-surface-100 px-3 py-1.5 text-xs font-semibold text-surface-content transition-colors hover:bg-surface-200"
                      >
                        Delete
                      </Button>
                    </form>
                  </div>
                {/each}
              </div>
            {/if}

            <form method="post" action={paths.user_wakatime_mirrors_path} class="mt-5 space-y-3">
              <input type="hidden" name="authenticity_token" value={csrfToken} />
              <div>
                <label for="endpoint_url" class="mb-2 block text-sm text-surface-content">
                  Endpoint URL
                </label>
                <input
                  id="endpoint_url"
                  type="url"
                  name="wakatime_mirror[endpoint_url]"
                  value="https://wakatime.com/api/v1"
                  required
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label for="mirror_key" class="mb-2 block text-sm text-surface-content">
                  WakaTime API Key
                </label>
                <input
                  id="mirror_key"
                  type="password"
                  name="wakatime_mirror[encrypted_api_key]"
                  required
                  class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                />
              </div>
              <Button unstyled
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              >
                Add mirror
              </Button>
            </form>
          </section>
        </div>
      {/if}
    </section>
  </div>
</div>
