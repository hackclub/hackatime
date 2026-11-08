<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import DetailField from "../../../components/DetailField.svelte";
  import { adminAdminApiKeys } from "../../../api";
  type Key = {
    id: number;
    name: string;
    token_preview: string;
    token: string | null;
    created_at: string;
    active: boolean;
    scopes: string[];
    all_scopes: boolean;
    expires_at: string | null;
    user: { id: number; display_name: string; avatar_url: string | null };
  };
  let { api_key, show_token }: { api_key: Key; show_token: boolean } = $props();
</script>

<svelte:head><title>Admin API key · Admin | Hackatime</title></svelte:head>
<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
  <div class="mb-8 flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold text-surface-content mb-2">
        lookin at {api_key.name}
      </h1>
      <p class="text-muted">get the deets</p>
    </div>
    <Link
      href={adminAdminApiKeys.index.path()}
      class="text-muted hover:text-surface-content">← Back to API Keys</Link
    >
  </div>
  <div class="grid grid-cols-1 gap-8">
    <div class="bg-dark rounded-lg p-6">
      <h2 class="text-xl font-semibold text-surface-content mb-4">deets</h2>
      {#if show_token}<div
          class="bg-green/30 border border-green/50 rounded-lg p-4 mb-6"
        >
          <h3 class="text-green font-medium mb-2">
            heres ya key, copy it now!
          </h3>
          <p class="text-green text-sm mb-3">
            copy it now, its not gonna be shown again silly
          </p>
          <div class="bg-surface-100 rounded p-3">
            <code
              class="block text-surface-content text-sm break-all select-all"
            >
              {api_key.token}
            </code>
          </div>
        </div>{/if}
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <DetailField label="name" variant="muted">
          <div class="text-surface-content">{api_key.name}</div>
        </DetailField>
        <DetailField label="spawned by" variant="muted">
          <div class="flex items-center">
            {#if api_key.user.avatar_url}<img
                class="h-6 w-6 rounded-full mr-2"
                src={api_key.user.avatar_url}
                alt=""
              />{/if}
            <div>
              <div class="text-surface-content">
                {api_key.user.display_name}
              </div>
              <div class="text-xs text-muted">ID: {api_key.user.id}</div>
            </div>
          </div>
        </DetailField>
        <DetailField label="spawned at" variant="muted">
          <div class="text-surface-content">{api_key.created_at}</div>
        </DetailField>
        <DetailField label="status" variant="muted">
          {#if !api_key.active}<div class="text-red">
              dead
            </div>{:else if api_key.expires_at}<div class="text-yellow">
              live until {api_key.expires_at}, then it gets revoked
            </div>{:else}<div class="text-green">live</div>{/if}
        </DetailField>
        <DetailField label="scopes" variant="muted" class="md:col-span-2">
          <div class="flex flex-wrap gap-2">
            {#each api_key.scopes as scope}<code
                class="bg-darkless px-2 py-1 rounded text-xs text-surface-content"
                >{scope}</code
              >{/each}
          </div>
        </DetailField>
        <DetailField
          label="token preview"
          variant="muted"
          class="md:col-span-2"
        >
          <code class="text-sm text-surface-content"
            >{api_key.token_preview}</code
          >
        </DetailField>
      </div>
      <div class="mt-6"></div>
      <Form
        action={adminAdminApiKeys.destroy.path({ id: api_key.id })}
        method="delete"
        ><Button
          type="submit"
          class="bg-red hover:bg-red text-on-primary px-4 py-2 rounded-lg font-medium transition-colors"
          >nuke it</Button
        ></Form
      >
    </div>
  </div>
</div>
