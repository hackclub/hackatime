<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import { adminAdminUsers } from "../../api";
  type User = {
    id: number;
    display_name: string;
    avatar_url: string;
    slack_uid: string | null;
    admin_level: string;
    allowed_levels: string[];
  };
  let {
    groups,
    current_user_id,
  }: { groups: Record<string, User[]>; current_user_id: number } = $props();
  let results = $state<User[] | null>(null);
  let timer: ReturnType<typeof setTimeout>;
  const headingClasses: Record<string, string> = {
    ultraadmin: "text-purple-400",
    superadmin: "text-red",
    admin: "text-yellow",
    viewer: "text-blue",
  };
  const buttonClasses: Record<string, string> = {
    ultraadmin: "bg-purple-400 text-on-primary hover:bg-purple-400",
    superadmin: "bg-red text-on-primary hover:bg-red",
    admin: "bg-yellow text-on-primary hover:bg-yellow",
    viewer: "bg-blue text-on-primary hover:bg-blue",
    default: "bg-surface-100 text-surface-content hover:bg-surface-100",
  };
  const roleClasses: Record<string, string> = {
    ultraadmin: "bg-purple-400/20 text-purple-400",
    superadmin: "bg-red/20 text-red",
    admin: "bg-yellow/20 text-yellow",
    viewer: "bg-blue/20 text-blue",
    default: "bg-surface-100/20 text-muted",
  };
  const labels: Record<string, string> = {
    ultraadmin: "Ultraadmin",
    superadmin: "Superadmin",
    admin: "Admin",
    viewer: "Viewer",
    default: "Default",
  };
  const confirmation = (user: User, level: string) => {
    if (level === "default")
      return `Remove ${user.display_name}'s ${user.admin_level === "viewer" ? "viewer" : "admin"} privileges?`;
    const ranks: Record<string, number> = {
      viewer: 1,
      admin: 2,
      superadmin: 3,
      ultraadmin: 4,
    };
    const verb = ranks[level] > ranks[user.admin_level] ? "Promote" : "Demote";
    return `${verb} ${user.display_name} to ${labels[level]}?`;
  };
  async function search(event: Event) {
    clearTimeout(timer);
    const q = (event.currentTarget as HTMLInputElement).value.trim();
    if (q.length < 2) {
      results = null;
      return;
    }
    timer = setTimeout(async () => {
      const response = await fetch(
        adminAdminUsers.search.path({ query: { q } }),
        { headers: { Accept: "application/json" } },
      );
      results = (await response.json()).users;
    }, 100);
  }
</script>

<svelte:head><title>Admin Management</title></svelte:head>
<div class="max-w-6xl mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">
      Admin Management
    </h1>
    <p class="text-muted">Who can access the admin panel?</p>
  </header>
  <div class="border border-primary rounded-xl p-6 bg-dark">
    <h2 class="text-2xl font-semibold text-green mb-4">Promote</h2>
    <div class="mb-4">
      <TextInput
        oninput={search}
        placeholder="Search by name or Slack ID..."
        class="w-full px-4 py-2 bg-darker border border-surface-200 rounded-lg text-surface-content placeholder-gray-500 focus:outline-none focus:border-primary"
      />
    </div>
    {#if results}{@render UserRows(results, true)}{/if}
  </div>
  {#each ["ultraadmin", "superadmin", "admin", "viewer"] as level}<div
      class="border border-primary rounded-xl p-6 bg-dark"
    >
      <h2 class="mb-4 text-2xl font-semibold {headingClasses[level]}">
        {labels[level]}s ({groups[level].length})
      </h2>
      {#if groups[level].length}<div class="overflow-x-auto">
          <table class="w-full text-left">
            <thead
              ><tr class="border-b border-surface-200"
                ><th class="py-3 px-4">User</th><th class="py-3 px-4"
                  >Slack ID</th
                >{#if groups[level].some((u) => u.allowed_levels.length)}<th
                    class="py-3 px-4">Actions</th
                  >{/if}</tr
              ></thead
            ><tbody>{@render UserRows(groups[level])}</tbody>
          </table>
        </div>{:else}<p class="text-muted">No {level}s found</p>{/if}
    </div>{/each}
</div>
{#snippet UserRows(
  users: User[],
  search = false,
)}{#each users as user}{#if search}<div
        class="flex items-center justify-between p-3 hover:bg-surface-100/50 bg-darker border border-surface-200"
      >
        <div>
          {@render User(user)}
          <div class="mt-1 flex items-center gap-2 pl-10">
            <span class="text-sm text-muted"
              >{user.slack_uid || "No Slack ID"}</span
            >
            <span
              class="rounded-full px-2 py-0.5 text-xs {roleClasses[
                user.admin_level
              ]}">{labels[user.admin_level]}</span
            >
          </div>
        </div>
        {@render Actions(user)}
      </div>{:else}<tr
        class="border-b border-surface-200 hover:bg-surface-100/50"
        ><td class="py-3 px-4">{@render User(user)}</td><td
          class="py-3 px-4 text-muted">{user.slack_uid || "N/A"}</td
        >{#if groups[user.admin_level].some((u) => u.allowed_levels.length)}<td
            class="py-3 px-4"
            >{#if user.allowed_levels.length}{@render Actions(
                user,
                true,
              )}{:else if user.id === current_user_id}<span
                class="text-muted text-sm">Cannot modify yourself</span
              >{/if}</td
          >{/if}</tr
      >{/if}{/each}{/snippet}
{#snippet User(user: User)}<div class="flex items-center gap-2">
    <img src={user.avatar_url} alt="Avatar" class="w-8 h-8 rounded-full" /><span
      class="text-surface-content">{user.display_name}</span
    >{#if user.id === current_user_id}<span
        class="px-2 py-0.5 text-xs rounded-full {user.admin_level ===
        'ultraadmin'
          ? 'bg-purple-400/20 text-purple-400'
          : 'bg-blue/20 text-blue'}">(you)</span
      >{/if}
  </div>{/snippet}
{#snippet Actions(user: User, confirmChange = false)}<div class="flex gap-2">
    {#each user.allowed_levels as level}<Form
        action={adminAdminUsers.update.path({
          id: user.id,
          query: { admin_level: level },
        })}
        method="patch"
        onsubmit={(event: SubmitEvent) => {
          if (confirmChange && !confirm(confirmation(user, level)))
            event.preventDefault();
        }}
        ><Button
          unstyled
          type="submit"
          class="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-colors {buttonClasses[
            level
          ]}">→ {labels[level]}</Button
        ></Form
      >{/each}
  </div>{/snippet}
