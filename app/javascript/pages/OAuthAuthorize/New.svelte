<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";
  import { customDoorkeeperAuthorizations } from "../../api";
  import {
    Check,
    ExclamationTriangle,
    Eye,
    Icon,
    ShieldCheck,
    User,
    type IconSource,
  } from "svelte-hero-icons";

  interface Scope {
    name: string;
    description: string;
  }

  interface FormData {
    csrf_token: string;
    client_id: string;
    redirect_uri: string;
    state: string;
    response_type: string;
    response_mode: string;
    scope: string;
    code_challenge: string;
    code_challenge_method: string;
  }

  let {
    page_title,
    client_name,
    verified,
    has_admin_scope = false,
    scopes,
    form_data,
  }: {
    page_title: string;
    client_name: string;
    verified: boolean;
    has_admin_scope?: boolean;
    scopes: Scope[];
    form_data: FormData;
  } = $props();

  const authorizePath = customDoorkeeperAuthorizations.new.path();

  let authorizing = $state(false);
  let denying = $state(false);

  const scopeIcons: Record<string, IconSource> = {
    profile: User,
    read: Eye,
    admin: ExclamationTriangle,
  };

  const redirectTarget = $derived.by(() => {
    if (!form_data.redirect_uri) return "the application";

    try {
      const origin = new URL(form_data.redirect_uri).origin;
      return origin === "null" ? form_data.redirect_uri : origin;
    } catch {
      return form_data.redirect_uri;
    }
  });

  const hiddenFields = $derived<[string, string][]>([
    ["authenticity_token", form_data.csrf_token],
    ["client_id", form_data.client_id],
    ["redirect_uri", form_data.redirect_uri],
    ["state", form_data.state],
    ["response_type", form_data.response_type],
    ["response_mode", form_data.response_mode],
    ["scope", form_data.scope],
    ["code_challenge", form_data.code_challenge],
    ["code_challenge_method", form_data.code_challenge_method],
  ]);
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="flex min-h-screen w-screen items-center justify-center px-4 py-4">
  <div class="w-full max-w-lg">
    <div class="mb-4">
      <h1
        class="text-balance text-center text-xl font-semibold tracking-tight text-surface-content"
      >
        Authorize {client_name}?
      </h1>
    </div>

    <div class="overflow-hidden rounded-xl border border-surface-200 bg-dark">
      <div class="p-3.5 sm:px-4">
        <div>
          <p
            class="text-pretty break-words text-sm font-semibold text-surface-content"
          >
            {client_name}
          </p>
          <p class="mt-0.5 text-pretty text-xs text-muted">
            wants to access your Hackatime account
          </p>
        </div>
      </div>

      {#if has_admin_scope}
        <div
          class="flex items-start gap-2.5 border-t border-red/40 bg-red/15 p-3.5 sm:px-4"
        >
          <div
            class="flex h-7 w-7 shrink-0 items-center justify-center text-red"
          >
            <Icon src={ExclamationTriangle} solid size="20" />
          </div>
          <div>
            <p class="text-sm font-bold tracking-tight text-red">
              You're giving access to admin data
            </p>
            <p class="mt-0.5 text-pretty text-xs font-semibold text-red">
              This app can use your admin privileges to manage users, trust
              levels, heartbeats and other internal data.
            </p>
          </div>
        </div>
      {/if}

      {#if !verified}
        <div
          class="flex items-start gap-2.5 border-t border-yellow/30 bg-yellow/10 p-3.5 sm:px-4"
        >
          <div
            class="flex h-7 w-7 shrink-0 items-center justify-center text-yellow"
          >
            <Icon src={ExclamationTriangle} solid size="20" />
          </div>
          <div>
            <p class="text-sm font-semibold text-yellow">
              Unverified application
            </p>
            <p class="mt-0.5 text-pretty text-xs text-yellow/80">
              This app has not been verified by HQ. Only authorize it if you
              trust the developer.
            </p>
          </div>
        </div>
      {/if}

      {#if scopes.length > 0}
        <div class="border-t border-surface-200">
          {#each scopes as scope}
            <div
              class="flex items-start gap-2.5 border-b border-surface-200/70 p-3.5 last:border-b-0 sm:px-4"
            >
              <div
                class="flex h-7 w-7 shrink-0 items-center justify-center text-muted"
              >
                <Icon
                  src={scopeIcons[scope.name] || Check}
                  size="22"
                  stroke-width="2"
                />
              </div>
              <div>
                <p class="text-sm font-semibold text-surface-content">
                  {scope.name === "profile"
                    ? "Personal profile data"
                    : scope.name === "read"
                      ? "Coding activity"
                      : scope.name === "admin"
                        ? "Administrative access"
                        : scope.name}
                </p>
                <p class="mt-0.5 text-pretty text-xs leading-normal text-muted">
                  {scope.description}
                </p>
              </div>
            </div>
          {/each}
        </div>
      {/if}

      <div class="border-t border-surface-200 bg-surface/30 p-3.5 sm:p-4">
        <div class="grid gap-3 sm:grid-cols-2">
          <form
            action={authorizePath}
            method="post"
            data-turbo="false"
            onsubmit={() => (denying = true)}
          >
            {#each hiddenFields as [name, value]}
              <input type="hidden" {name} {value} />
            {/each}
            <input type="hidden" name="_method" value="delete" />
            <Button
              type="submit"
              variant="surface"
              size="sm"
              class="min-h-11 w-full cursor-pointer"
              disabled={authorizing || denying}
            >
              {#if denying}
                Cancelling…
              {:else}
                Cancel
              {/if}
            </Button>
          </form>

          <form
            action={authorizePath}
            method="post"
            data-turbo="false"
            onsubmit={() => (authorizing = true)}
          >
            {#each hiddenFields as [name, value]}
              <input type="hidden" {name} {value} />
            {/each}
            <Button
              type="submit"
              variant="primary"
              size="sm"
              class="min-h-11 w-full cursor-pointer"
              disabled={authorizing || denying}
            >
              {#if authorizing}
                Authorizing…
              {:else}
                Authorize
              {/if}
            </Button>
          </form>
        </div>

        <p class="mt-3 text-center text-xs text-muted">
          Authorizing will redirect to
          <span class="break-all font-semibold text-surface-content"
            >{redirectTarget}</span
          >
        </p>
      </div>
    </div>

    {#if verified}
      <div
        class="mt-3 flex items-center justify-center gap-1.5 text-xs text-muted"
      >
        <Icon src={ShieldCheck} size="18" />
        Verified by Hack Club HQ
      </div>
    {/if}
  </div>
</div>
