<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import { adminAdminApiKeys } from "../../../api";
  type Key = {
    id: number;
    name: string;
    token_preview: string;
    created_at: string;
    user: { id: number; display_name: string; avatar_url: string | null };
  };
  let {
    api_keys,
    can_create_keys,
  }: { api_keys: Key[]; can_create_keys: boolean } = $props();
</script>

<svelte:head><title>Admin API Keys</title></svelte:head>
<div>
  <div class="mb-8 flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold text-surface-content mb-2">
        admin api keys
      </h1>
      <p class="text-muted">
        fraud team is gonna foam at the mouth for this shit
      </p>
    </div>
    {#if can_create_keys}<Link
        href={adminAdminApiKeys.new.path()}
        class="bg-red text-on-primary px-4 py-2 rounded-lg font-medium transition-colors hover:bg-red"
        >spawn in a new key</Link
      >{:else}<Button
        disabled
        title="viewers can't make keys"
        class="bg-red text-on-primary px-4 py-2 rounded-lg font-medium transition-colors opacity-50 cursor-not-allowed"
        >spawn in a new key</Button
      >{/if}
  </div>
  <div class="bg-dark rounded-lg overflow-hidden shadow-xl">
    <div class="overflow-x-auto">
      <table class="min-w-full">
        <thead
          ><tr class="bg-darkless"
            >{#each ["name", "spawned by", "spawned at", "token", "perform"] as heading}<th
                class="px-6 py-3 text-left text-sm font-medium text-muted"
                >{heading}</th
              >{/each}</tr
          ></thead
        >
        <tbody class="divide-y divide-gray-950"
          >{#each api_keys as key}<tr class="hover:bg-darkless"
              ><td
                class="px-6 py-4 whitespace-nowrap text-sm font-medium text-surface-content"
                >{key.name}</td
              ><td class="px-6 py-4 whitespace-nowrap"
                ><div class="flex items-center">
                  {#if key.user.avatar_url}<img
                      class="h-6 w-6 rounded-full mr-2"
                      src={key.user.avatar_url}
                      alt="key creator avatar"
                    />{/if}
                  <div>
                    <div class="text-sm text-surface-content">
                      {key.user.display_name}
                    </div>
                    <div class="text-xs text-muted">ID: {key.user.id}</div>
                  </div>
                </div></td
              ><td class="px-6 py-4 whitespace-nowrap text-sm text-muted"
                >{key.created_at}</td
              ><td class="px-6 py-4 whitespace-nowrap"
                ><code class="text-xs text-surface-content">
                  {key.token_preview}
                </code></td
              ><td
                class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2"
                ><Link
                  href={adminAdminApiKeys.show.path({ id: key.id })}
                  class="text-blue hover:text-blue">inspect</Link
                ><Form
                  action={adminAdminApiKeys.destroy.path({ id: key.id })}
                  method="delete"
                  class="inline"
                  ><Button
                    unstyled
                    type="submit"
                    class="text-red hover:text-red">nuke</Button
                  ></Form
                ></td
              ></tr
            >{/each}</tbody
        >
      </table>
    </div>
    {#if !api_keys.length}<div class="text-center py-12">
        <div class="text-muted text-lg mb-2">nothing here cuzo</div>
        <p class="text-muted mb-4">
          you can make a new key if you wanna, or not
        </p>
      </div>{/if}
  </div>
</div>
