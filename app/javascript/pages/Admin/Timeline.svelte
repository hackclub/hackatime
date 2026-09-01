<script lang="ts">
  import { untrack } from "svelte";
  import { Form, Link } from "@inertiajs/svelte";
  import AdminUserMention from "../../components/AdminUserMention.svelte";
  import Button from "../../components/Button.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import UserSearchCombobox from "../../components/UserSearchCombobox.svelte";
  import { adminTimeline, users } from "../../api";

  type UserSummary = {
    id: number;
    display_name: string;
    avatar_url: string | null;
  };
  type Project = { name: string; repo_url: string | null };
  type Span = {
    start_epoch: number;
    end_epoch: number;
    title: string;
    projects: Project[];
    languages: string;
    time: string;
  };
  type Column = {
    user: UserSummary & {
      timezone: string;
      slack_url: string | null;
      github_url: string | null;
      trust_level: string;
      can_impersonate: boolean;
    };
    total: number;
    total_short: string;
    total_detailed: string;
    day_start_epoch: number;
    spans: Span[];
  };
  type Commit = {
    user_id: number;
    timestamp: number;
    github_url: string;
    additions: number | null;
    deletions: number | null;
  };

  let {
    current_user,
    selected_users,
    date,
    date_label,
    today,
    columns,
    commits,
  }: {
    current_user: UserSummary & { admin_level: string };
    selected_users: UserSummary[];
    date: string;
    date_label: string;
    today: string;
    columns: Column[];
    commits: Commit[];
  } = $props();

  const HOUR_LABEL_WIDTH = 80;
  const COLUMN_WIDTH = 186;
  const GUTTER = 4;
  const HEADER_HEIGHT = 120;
  const PIXELS_PER_HOUR = 128;
  const DAY_SECONDS = 24 * 3600;
  const COLORS = [
    "#7C3AED",
    "#10B981",
    "#3B82F6",
    "#F59E0B",
    "#EF4444",
    "#DB2777",
    "#6D28D9",
  ];

  const columnLeft = (index: number) =>
    HOUR_LABEL_WIDTH + index * (COLUMN_WIDTH + GUTTER);
  const columnColor = (index: number) => COLORS[index % COLORS.length];
  const epochTop = (epoch: number, dayStartEpoch: number) =>
    HEADER_HEIGHT + ((epoch - dayStartEpoch) / 3600) * PIXELS_PER_HOUR;
  const positionSpans = (column: Column) =>
    column.spans.flatMap((span) => {
      const start = Math.max(span.start_epoch, column.day_start_epoch);
      const end = Math.min(
        span.end_epoch,
        column.day_start_epoch + DAY_SECONDS,
      );
      const height =
        Math.round(((end - start) / 3600) * PIXELS_PER_HOUR * 100) / 100;
      if (height <= 0.5) return [];
      return [
        {
          ...span,
          top: Math.round(epochTop(start, column.day_start_epoch)),
          height,
        },
      ];
    });

  let selected = $state<UserSummary[]>(untrack(() => selected_users));
  const canMutate = $derived(
    ["admin", "superadmin", "ultraadmin"].includes(current_user.admin_level),
  );
  const isSuperadmin = $derived(
    ["superadmin", "ultraadmin"].includes(current_user.admin_level),
  );
  const selectedIds = $derived(selected.map((user) => user.id).join(","));
  const gridWidth = $derived(
    HOUR_LABEL_WIDTH + columns.length * (COLUMN_WIDTH + GUTTER),
  );
  const gridHeight = HEADER_HEIGHT + 24 * PIXELS_PER_HOUR;
  const positionedCommits = $derived(
    commits.flatMap((commit) => {
      const index = columns.findIndex(({ user }) => user.id === commit.user_id);
      if (index === -1) return [];
      return [
        {
          ...commit,
          left: columnLeft(index) + 93,
          top: Math.round(
            epochTop(commit.timestamp, columns[index].day_start_epoch),
          ),
        },
      ];
    }),
  );
  let nowEpoch = $state(Date.now() / 1000);
  $effect(() => {
    const timer = setInterval(() => (nowEpoch = Date.now() / 1000), 30_000);
    return () => clearInterval(timer);
  });
  let gridScroller = $state<HTMLDivElement | null>(null);
  // On load and whenever the data changes (View, Prev/Next), center the grid
  // on the current time of day in the primary column's timezone.
  $effect(() => {
    if (!columns.length || !gridScroller) return;
    const dayStart = columns[0].day_start_epoch;
    const offset =
      (((Date.now() / 1000 - dayStart) % DAY_SECONDS) + DAY_SECONDS) %
      DAY_SECONDS;
    const target = HEADER_HEIGHT + (offset / 3600) * PIXELS_PER_HOUR;
    gridScroller.scrollTop = Math.max(
      0,
      target - gridScroller.clientHeight / 2,
    );
  });
  const nowTop = $derived.by(() => {
    const dayStart = columns[0]?.day_start_epoch;
    if (dayStart === undefined) return null;
    const offset = nowEpoch - dayStart;
    if (offset < 0 || offset >= DAY_SECONDS) return null;
    return epochTop(nowEpoch, dayStart);
  });
  const trusts: Record<string, { emoji: string; name: string; level: string }> =
    {
      green: { emoji: "🟢", name: "Green - Trusted", level: "green" },
      "1": { emoji: "🟢", name: "Green - Trusted", level: "green" },
      yellow: { emoji: "🟡", name: "Yellow - Suspected", level: "yellow" },
      "2": { emoji: "🟡", name: "Yellow - Suspected", level: "yellow" },
      red: { emoji: "🔴", name: "Red - Convicted (banned)", level: "red" },
      "3": { emoji: "🔴", name: "Red - Convicted (banned)", level: "red" },
      blue: { emoji: "🔵", name: "Blue - Unscored", level: "blue" },
      "4": { emoji: "🔵", name: "Blue - Unscored", level: "blue" },
    };
  const trustEmoji = (level: string) => trusts[level]?.emoji ?? "🔵";
  const trustBackground = (level: string) =>
    ({
      red: "bg-red/20",
      green: "bg-green/20",
      yellow: "bg-yellow/20",
      blue: "bg-blue/20",
    })[level] ?? "bg-surface-100/20";
  const adjacentDate = (days: number) => {
    const value = new Date(`${date}T12:00:00Z`);
    value.setUTCDate(value.getUTCDate() + days);
    return value.toISOString().slice(0, 10);
  };

  $effect(() => {
    selected = selected_users;
  });

  function selectUser(user: UserSummary) {
    if (!selected.some(({ id }) => id === user.id))
      selected = [...selected, user];
  }
  const canSearchUsers = (query: string) =>
    query.length >= 2 || /^\d+$/.test(query);
  async function applyPreset(period: string) {
    const response = await fetch(
      adminTimeline.leaderboardUsers.path({ query: { period } }),
    );
    if (!response.ok)
      return alert("Could not load preset users. Please try again.");
    selected = (await response.json()).users;
  }
  async function setTrust(column: Column) {
    if (!canMutate) return alert("you dont have human rights to do that");
    let options =
      "🟢 Green (1) - Trusted\n🟡 Yellow (2) - Suspected\n🔵 Blue (4) - Unscored";
    if (isSuperadmin)
      options =
        "🟢 Green (1) - Trusted\n🟡 Yellow (2) - Suspected\n🔴Red (3) - Convicted (banned)\n🔵 Blue (4) - Unscored";
    const input = prompt(
      `set the trust for ${column.user.id}\n\n${options}\n\nenter number or color`,
    );
    const trust = input && trusts[input.toLowerCase().trim()];
    if (!trust) return input && alert("read the popup idiot");
    if (trust.level === "red" && !isSuperadmin) return alert("nice try neon");
    const reason = prompt(
      "please explain why you are doing this to this poor soul",
    );
    if (!reason?.trim()) return alert("you gotta put something down silly");
    const notes = prompt("anything else you wanna add? (optional)");
    const response = await fetch(
      users.updateTrustLevel.path({ id: column.user.id }),
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":
            document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
              ?.content ?? "",
        },
        body: JSON.stringify({
          trust_level: trust.level,
          reason: reason.trim(),
          notes: notes?.trim() ?? "",
        }),
      },
    );
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      return alert(`shit ${error.error ?? response.statusText}`);
    }
    column.user.trust_level = trust.level;
    alert(
      `set trust to ${trust.name}\nreason: ${reason}${notes ? `\nanything else? ${notes}` : ""}`,
    );
  }
</script>

<svelte:head><title>Admin Timeline</title></svelte:head>
<div class="flex h-screen flex-col p-5 font-sans text-surface-content">
  <div class="mb-4 shrink-0 rounded-md bg-dark p-3">
    <Form action={adminTimeline.show.path()} method="get">
      <input type="hidden" name="user_ids" value={selectedIds} /><input
        type="hidden"
        name="date"
        value={date}
      />
      <div class="flex items-center gap-3">
        <UserSearchCombobox
          searchUrl={adminTimeline.searchUsers.path()}
          id="timeline-user-search"
          onselect={selectUser}
          searchWhen={canSearchUsers}
        >
          {#snippet children({
            query,
            results,
            open,
            highlight,
            searching,
            searchError,
            listboxId,
            activeDescendant,
            setQuery,
            select,
            handleKeydown,
            handleOptionKeydown,
            openResults,
            closeResults,
          })}
            <div class="relative flex-1">
              <div class="relative">
                <span
                  class="absolute left-3 top-1/2 -translate-y-1/2 text-muted"
                >
                  {#if searching}<svg
                      class="h-4 w-4 animate-spin"
                      fill="none"
                      viewBox="0 0 24 24"
                      aria-label="Searching"
                      ><circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      ></circle><path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      ></path></svg
                    >{:else}<svg
                      class="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                      ><path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                      ></path></svg
                    >{/if}
                </span>
                <label for="timeline-user-search" class="sr-only">
                  Search users
                </label>
                <TextInput
                  id="timeline-user-search"
                  value={query}
                  oninput={(event) => setQuery(event.currentTarget.value)}
                  onkeydown={handleKeydown}
                  onfocus={openResults}
                  onblur={() => setTimeout(closeResults, 200)}
                  autocomplete="off"
                  placeholder="Add user by name/email/id..."
                  role="combobox"
                  aria-autocomplete="list"
                  aria-controls={listboxId}
                  aria-expanded={open}
                  aria-activedescendant={activeDescendant}
                  class="w-full rounded-md bg-darker py-2 pl-10 pr-3 text-sm text-surface-content placeholder-gray-300 focus:border-transparent focus:outline-none"
                />
              </div>
              {#if open}<div
                  id={listboxId}
                  class="absolute left-0 top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-surface-200 bg-dark shadow-lg"
                  role="listbox"
                  aria-label="Search users"
                >
                  {#if searchError}<div class="px-4 py-2 text-sm text-red">
                      Error searching users
                    </div>{:else if results.length === 0}<div
                      class="px-4 py-2 text-sm text-muted"
                    >
                      No users found
                    </div>{/if}
                  {#each results as user, index}<button
                      id={`timeline-user-search-result-${user.id}`}
                      type="button"
                      role="option"
                      aria-selected={index === highlight}
                      onmousedown={(event) => event.preventDefault()}
                      onclick={() => select(user)}
                      onkeydown={(event) => handleOptionKeydown(event, user)}
                      class="my-1 mx-2 flex w-[calc(100%-1rem)] cursor-pointer items-center rounded-lg border px-3 py-2 text-sm text-surface-content transition-colors hover:border-surface-200 hover:bg-darkless {index ===
                      highlight
                        ? 'border-surface-200 bg-darkless'
                        : 'border-transparent'}"
                    >
                      {#if user.avatar_url}<img
                          src={user.avatar_url}
                          alt={user.display_name}
                          class="mr-3 h-5 w-5 rounded-full"
                        />{/if}<span>{user.display_name}</span><span
                        class="ml-auto rounded-full bg-surface-100 px-2 py-1 text-xs text-muted"
                        >#{user.id}</span
                      >
                    </button>{/each}
                </div>{/if}
            </div>
          {/snippet}
        </UserSearchCombobox>
        <Button
          unstyled
          type="button"
          class="rounded-md bg-darker px-3 py-2 text-sm text-surface-content transition-colors"
          onclick={() => applyPreset("today")}>Top 15 Today</Button
        >
        <Button
          unstyled
          type="button"
          class="rounded-md bg-darker px-3 py-2 text-sm text-surface-content transition-colors"
          onclick={() => applyPreset("last_7_days")}>Top 15 Week</Button
        >
        <Button
          unstyled
          type="submit"
          class="rounded-md bg-green px-4 py-2 text-sm font-medium text-on-primary transition-colors"
          >View</Button
        >
      </div>
      <div class="mt-2 min-h-7">
        {#each selected as user}<span
            class="mr-2 mb-2 inline-flex items-center rounded-lg px-3 py-1 text-sm {user.id ===
            current_user.id
              ? 'bg-blue font-medium text-on-primary'
              : 'bg-surface-100 text-surface-content'}"
          >
            {#if user.avatar_url}<img
                src={user.avatar_url}
                alt={user.display_name}
                class="mr-2 h-4 w-4 rounded-full"
              />{/if}<span class="mr-2">{user.display_name}</span><span
              class="rounded-md px-2 py-0.5 text-xs">#{user.id}</span
            >
            {#if user.id !== current_user.id}<button
                type="button"
                aria-label="Remove user"
                onclick={() =>
                  (selected = selected.filter(({ id }) => id !== user.id))}
                class="ml-2 text-lg leading-none text-muted hover:text-surface-content"
                >×</button
              >{/if}
          </span>{/each}
      </div>
    </Form>
  </div>
  <div class="mb-4 flex shrink-0 items-center justify-between">
    <div class="text-lg font-semibold">{date_label}</div>
    <div class="flex gap-2">
      <Link
        href={adminTimeline.show.path()}
        data={{ date: adjacentDate(-1), user_ids: selectedIds }}
        class="rounded bg-darker px-3 py-1 text-sm">← Prev</Link
      ><Link
        href={adminTimeline.show.path()}
        data={{ date: today, user_ids: selectedIds }}
        class="rounded bg-darker px-3 py-1 text-sm">Today</Link
      ><Link
        href={adminTimeline.show.path()}
        data={{ date: adjacentDate(1), user_ids: selectedIds }}
        class="rounded bg-darker px-3 py-1 text-sm">Next →</Link
      >
    </div>
  </div>
  <div
    bind:this={gridScroller}
    class="min-h-0 flex-1 overflow-x-auto overflow-y-auto"
  >
    {#if columns.length}
      <div
        class="relative"
        style:width={`${gridWidth}px`}
        style:height={`${gridHeight}px`}
      >
        <div
          class="sticky top-0 z-40 bg-darker"
          style:height={`${HEADER_HEIGHT}px`}
        >
          {#each columns as column, index}
            <div
              class="absolute top-0 overflow-hidden rounded-lg p-3 shadow-lg {trustBackground(
                column.user.trust_level,
              )}"
              style:left={`${columnLeft(index) + 2}px`}
              style:width={`${COLUMN_WIDTH - 4}px`}
              style:height={`${HEADER_HEIGHT - 8}px`}
              title={`User ID: ${column.user.id} - ${column.user.display_name} | Total Coded: ${column.total > 0 ? column.total_detailed : "0m"} | TZ: ${column.user.timezone}`}
            >
              <div
                class="mb-1 flex min-w-0 items-center gap-2 [&_span]:min-w-0 [&_span]:truncate"
              >
                <AdminUserMention user={column.user} />
              </div>
              <div
                class="mb-1 flex items-center justify-center gap-4 text-center"
              >
                {#if column.user.slack_url}<a
                    href={column.user.slack_url}
                    target="_blank"
                    class="text-xs text-blue underline">Slack</a
                  >{/if}{#if column.user.github_url}<a
                    href={column.user.github_url}
                    target="_blank"
                    class="text-xs text-green underline">Git</a
                  >{/if}<span class="text-sm"
                  >{trustEmoji(column.user.trust_level)}</span
                >{#if canMutate && column.user.id !== current_user.id}<button
                    type="button"
                    onclick={() => setTrust(column)}
                    class="text-xs text-muted hover:text-surface-content"
                    title="Set trust level">🔨</button
                  >{/if}
              </div>
              <div
                class="mb-1 text-sm font-medium {column.total > 0
                  ? 'text-green'
                  : 'text-muted'}"
              >
                {column.total > 0
                  ? `${column.total_short} coded`
                  : "No time coded"}
              </div>
              <div class="text-xs text-muted">{column.user.timezone}</div>
            </div>
          {/each}
        </div>
        {#each Array(24) as _, hour}<div
            class="absolute left-0 w-full border-t border-surface-200"
            style:top={`${HEADER_HEIGHT + hour * PIXELS_PER_HOUR}px`}
            style:height={`${PIXELS_PER_HOUR}px`}
          >
            <div
              class="absolute left-2 top-2 px-1 font-mono text-xs text-muted"
            >
              {new Date(Date.UTC(2000, 0, 1, hour)).toLocaleTimeString(
                "en-US",
                { hour: "numeric", minute: "2-digit", timeZone: "UTC" },
              )}
            </div>
          </div>{/each}
        {#each columns as column, index}
          <div
            class="absolute bottom-0 border-r border-surface-200"
            style:top={`${HEADER_HEIGHT}px`}
            style:left={`${columnLeft(index)}px`}
            style:width={`${COLUMN_WIDTH}px`}
          ></div>
          {#each positionSpans(column) as span}<div
              class="absolute z-10 overflow-hidden rounded-md p-2 text-xs text-surface-content"
              style:background-color={columnColor(index)}
              style:left={`${columnLeft(index) + 2}px`}
              style:width={`${COLUMN_WIDTH - 4}px`}
              style:top={`${span.top}px`}
              style:height={`${span.height}px`}
              title={span.title}
            >
              <div class="truncate font-medium">
                {#if span.projects.length}{#each span.projects as project, index}{#if project.repo_url}<a
                        href={project.repo_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-surface-content underline hover:text-muted"
                        >{project.name.slice(0, 20)}</a
                      >{:else}<span
                        title={`${project.name} - No GitHub Repo Mapped`}
                        >{project.name.slice(0, 20)} 🚫</span
                      >{/if}{#if index < span.projects.length - 1 && span.height > 20}
                      /
                    {/if}{/each}{:else}Coding Activity{/if}
              </div>
              <div class="truncate opacity-90">{span.languages}</div>
              <div class="truncate opacity-75">{span.time}</div>
            </div>{/each}
        {/each}
        {#if nowTop !== null}<div
            class="absolute z-30 flex h-0.5 w-full items-center bg-red"
            style:left={`${HOUR_LABEL_WIDTH}px`}
            style:top={`${nowTop}px`}
          >
            <div
              class="-ml-16 rounded bg-red px-2 py-1 text-xs text-on-primary"
            >
              NOW
            </div>
          </div>{/if}
        {#each positionedCommits as commit}<a
            href={commit.github_url}
            target="_blank"
            rel="noopener noreferrer"
            class="absolute z-20 -translate-x-1/2 rounded-full bg-darker px-2 py-1 text-xs text-surface-content transition-colors hover:bg-surface-100"
            style:left={`${commit.left}px`}
            style:top={`${commit.top}px`}
            ><span
              class:text-green={(commit.additions ?? 0) > 0}
              class:font-semibold={(commit.additions ?? 0) > 0}
              >+{commit.additions}</span
            >
            /
            <span
              class:text-red={(commit.deletions ?? 0) > 0}
              class:font-semibold={(commit.deletions ?? 0) > 0}
              >-{commit.deletions}</span
            ></a
          >{/each}
      </div>
    {:else}<div class="flex h-64 items-center justify-center text-muted">
        <div class="text-center">
          <div class="mb-2 text-lg">No users selected</div>
          <div class="text-sm">
            Use the search bar above to add users to the timeline
          </div>
        </div>
      </div>{/if}
  </div>
</div>
