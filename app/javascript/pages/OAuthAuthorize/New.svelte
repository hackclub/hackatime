<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";

  interface Scope {
    name: string;
    description: string;
  }

  interface FormData {
    authorize_path: string;
    client_id: string;
    redirect_uri: string;
    state: string;
    response_type: string;
    response_mode: string;
    scope: string;
    code_challenge: string;
    code_challenge_method: string;
  }

  interface Props {
    page_title: string;
    client_name: string;
    verified: boolean;
    scopes: Scope[];
    form_data: FormData;
  }

  let { page_title, client_name, verified, scopes, form_data }: Props =
    $props();

  const csrfToken =
    typeof document === "undefined"
      ? ""
      : document
          .querySelector("meta[name='csrf-token']")
          ?.getAttribute("content") || "";

  let authorizing = $state(false);
  let denying = $state(false);

  const handleSubmit = (form: HTMLFormElement) => {
    form.requestSubmit();
  };

  const scopeIcons: Record<string, string> = {
    profile:
      "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z",
    read: "M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z",
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="flex min-h-screen w-screen items-center justify-center p-4">
  <div class="w-full max-w-md">
    <div class="mb-6 text-center">
      <h1 class="text-2xl font-bold text-surface-content">
        Authorize application?
      </h1>
      <p class="mt-2 text-sm text-muted">
        <span class="font-semibold text-primary">{client_name}</span> wants to access
        your Hackatime account
      </p>
    </div>

    {#if !verified}
      <div
        class="mb-5 flex items-start gap-3 rounded-xl border border-yellow/30 bg-yellow/10 p-4"
      >
        <svg
          class="mt-0.5 h-5 w-5 shrink-0 text-yellow"
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path
            fill-rule="evenodd"
            d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
            clip-rule="evenodd"
          />
        </svg>
        <div>
          <p class="text-sm font-medium text-yellow">Unverified application</p>
          <p class="mt-0.5 text-xs text-yellow/80">
            This app has not been verified by HQ. Only authorize if you trust
            the developer.
          </p>
        </div>
      </div>
    {/if}

    {#if scopes.length > 0}
      <div class="mb-5 rounded-xl border border-surface-200 bg-dark p-5">
        <p class="mb-3 text-xs font-medium uppercase tracking-wider text-muted">
          This will allow {client_name} to
        </p>
        <ul class="space-y-3">
          {#each scopes as scope}
            <li class="flex items-start gap-3">
              <div
                class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10"
              >
                <svg
                  class="h-4 w-4 text-primary"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d={scopeIcons[scope.name] || "M4.5 12.75l6 6 9-13.5"}
                  />
                </svg>
              </div>
              <p class="text-sm text-surface-content">
                {scope.description}
              </p>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <div class="space-y-2.5">
      <form
        method="post"
        action={form_data.authorize_path}
        data-turbo="false"
        onsubmit={() => (authorizing = true)}
      >
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <input type="hidden" name="client_id" value={form_data.client_id} />
        <input
          type="hidden"
          name="redirect_uri"
          value={form_data.redirect_uri}
        />
        <input type="hidden" name="state" value={form_data.state} />
        <input
          type="hidden"
          name="response_type"
          value={form_data.response_type}
        />
        <input
          type="hidden"
          name="response_mode"
          value={form_data.response_mode}
        />
        <input type="hidden" name="scope" value={form_data.scope} />
        <input
          type="hidden"
          name="code_challenge"
          value={form_data.code_challenge}
        />
        <input
          type="hidden"
          name="code_challenge_method"
          value={form_data.code_challenge_method}
        />
        <Button
          type="submit"
          variant="primary"
          size="lg"
          class="w-full"
          disabled={authorizing || denying}
        >
          {#if authorizing}
            <svg
              class="mr-2 h-4 w-4 animate-spin"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              ></circle>
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              ></path>
            </svg>
            Authorizing…
          {:else}
            Authorize {client_name}
          {/if}
        </Button>
      </form>

      <form
        method="post"
        action={form_data.authorize_path}
        data-turbo="false"
        onsubmit={() => (denying = true)}
      >
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <input type="hidden" name="_method" value="delete" />
        <input type="hidden" name="client_id" value={form_data.client_id} />
        <input
          type="hidden"
          name="redirect_uri"
          value={form_data.redirect_uri}
        />
        <input type="hidden" name="state" value={form_data.state} />
        <input
          type="hidden"
          name="response_type"
          value={form_data.response_type}
        />
        <input
          type="hidden"
          name="response_mode"
          value={form_data.response_mode}
        />
        <input type="hidden" name="scope" value={form_data.scope} />
        <input
          type="hidden"
          name="code_challenge"
          value={form_data.code_challenge}
        />
        <input
          type="hidden"
          name="code_challenge_method"
          value={form_data.code_challenge_method}
        />
        <Button
          type="submit"
          variant="surface"
          size="lg"
          class="w-full"
          disabled={authorizing || denying}
        >
          {#if denying}
            Denying…
          {:else}
            Deny
          {/if}
        </Button>
      </form>
    </div>

    <p class="mt-5 text-center text-xs text-muted">
      Authorizing will redirect you to the application
    </p>
  </div>
</div>
