<script lang="ts">
  import Button from "../../components/Button.svelte";
  import type { OAuthApplicationFormProps } from "./types";

  let {
    submit_path,
    form_method,
    cancel_path,
    labels,
    help_text,
    allow_blank_redirect_uri,
    application,
    scope_options,
    errors,
  }: OAuthApplicationFormProps = $props();

  const csrfToken =
    typeof document === "undefined"
      ? ""
      : document
          .querySelector("meta[name='csrf-token']")
          ?.getAttribute("content") || "";

  let selectedScopes = $state([...(application.selected_scopes || [])]);
  let confidential = $state(Boolean(application.confidential));
  let redirectUri = $state(application.redirect_uri);

  const nameLocked = $derived(application.persisted && application.verified);
</script>

{#if errors.full_messages.length > 0}
  <div class="rounded-xl border border-red/40 bg-red/10 p-4">
    <p class="text-sm font-semibold text-red">Fix the following errors:</p>
    <ul class="mt-2 list-disc space-y-1 pl-5 text-sm text-red/85">
      {#each errors.full_messages as error}
        <li>{error}</li>
      {/each}
    </ul>
  </div>
{/if}

<form method="post" action={submit_path} class="space-y-5">
  {#if form_method === "patch"}
    <input type="hidden" name="_method" value="patch" />
  {/if}
  <input type="hidden" name="authenticity_token" value={csrfToken} />

  <section class="rounded-xl border border-surface-200 bg-dark p-6">
    <h2 class="text-lg font-semibold text-surface-content">
      Application details
    </h2>

    <div class="mt-5 space-y-5">
      <div>
        <label
          for="doorkeeper_application_name"
          class="mb-2 block text-sm font-medium text-surface-content"
        >
          Name
        </label>

        {#if nameLocked}
          <input
            id="doorkeeper_application_name"
            type="text"
            value={application.name}
            class="w-full cursor-not-allowed rounded-md border border-surface-200 bg-darker/60 px-3 py-2 text-sm text-muted"
            disabled
          />
          <input
            type="hidden"
            name="doorkeeper_application[name]"
            value={application.name}
          />
          <p class="mt-2 text-xs text-yellow">
            Name is locked for verified applications. Contact a superadmin to
            change it.
          </p>
        {:else}
          <input
            id="doorkeeper_application_name"
            name="doorkeeper_application[name]"
            value={application.name}
            required
            placeholder="My Awesome App"
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
          />
        {/if}

        {#if errors.name.length > 0}
          <p class="mt-1 text-xs text-red">{errors.name[0]}</p>
        {/if}
      </div>

      <div>
        <label
          for="doorkeeper_application_redirect_uri"
          class="mb-2 block text-sm font-medium text-surface-content"
        >
          Redirect URIs
        </label>
        <textarea
          id="doorkeeper_application_redirect_uri"
          name="doorkeeper_application[redirect_uri]"
          rows="4"
          bind:value={redirectUri}
          placeholder="https://example.com/auth/callback"
          class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 font-mono text-sm text-surface-content focus:border-primary focus:outline-none"
        ></textarea>
        <p class="mt-2 text-xs text-muted">{help_text.redirect_uri}</p>
        {#if allow_blank_redirect_uri}
          <p class="mt-1 text-xs text-muted">{help_text.blank_redirect_uri}</p>
        {/if}

        {#if errors.redirect_uri.length > 0}
          <p class="mt-1 text-xs text-red">{errors.redirect_uri[0]}</p>
        {/if}
      </div>

      <div>
        <p class="mb-2 block text-sm font-medium text-surface-content">
          Scopes
        </p>
        <input
          type="hidden"
          name="doorkeeper_application[scopes]"
          value={selectedScopes.join(" ")}
        />

        <div class="space-y-2">
          {#each scope_options as scope}
            <label
              class="flex cursor-pointer items-start gap-3 rounded-lg border border-surface-200 bg-darker/70 p-3 hover:border-surface-300"
              for={`scope_${scope.value}`}
            >
              <input
                id={`scope_${scope.value}`}
                type="checkbox"
                value={scope.value}
                bind:group={selectedScopes}
                class="mt-1 h-4 w-4 rounded border-surface-300 bg-darker text-primary"
              />
              <span>
                <span class="text-sm font-medium text-surface-content">
                  {scope.value}
                  {#if scope.default}
                    <span class="ml-1 text-xs text-primary">(default)</span>
                  {/if}
                </span>
                <span class="mt-1 block text-xs text-muted"
                  >{scope.description}</span
                >
              </span>
            </label>
          {/each}
        </div>

        {#if errors.scopes.length > 0}
          <p class="mt-1 text-xs text-red">{errors.scopes[0]}</p>
        {/if}
      </div>

      <label
        class="flex cursor-pointer items-start gap-3 rounded-lg border border-surface-200 bg-darker/70 p-3 hover:border-surface-300"
        for="doorkeeper_application_confidential"
      >
        <input
          type="hidden"
          name="doorkeeper_application[confidential]"
          value="0"
        />
        <input
          id="doorkeeper_application_confidential"
          type="checkbox"
          name="doorkeeper_application[confidential]"
          value="1"
          bind:checked={confidential}
          class="mt-1 h-4 w-4 rounded border-surface-300 bg-darker text-primary"
        />
        <span>
          <span class="text-sm font-medium text-surface-content"
            >Confidential application</span
          >
          <span class="mt-1 block text-xs text-muted"
            >{help_text.confidential}</span
          >
        </span>
      </label>
    </div>
  </section>

  <div class="flex flex-wrap gap-3">
    <Button type="submit" variant="primary">{labels.submit}</Button>
    <Button href={cancel_path} variant="surface">{labels.cancel}</Button>
  </div>
</form>
