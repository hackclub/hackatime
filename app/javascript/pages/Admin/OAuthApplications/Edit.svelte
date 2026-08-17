<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import CheckboxField from "../../../components/CheckboxField.svelte";
  import PageIcon from "../../../components/PageIcon.svelte";
  import TextInput from "../../../components/TextInput.svelte";
  import { adminOauthApplications } from "../../../api";
  type Application = {
    id: number;
    name: string;
    redirect_uri: string;
    scopes: string;
    confidential: boolean;
    redirect_to_hca_login: boolean;
    verified: boolean;
  };
  let {
    application,
    errors,
  }: { application: Application; errors: Record<string, string[]> } = $props();
  let name = $state(""),
    redirectUri = $state(""),
    scopes = $state(""),
    confidential = $state(false),
    hcaLogin = $state(false);
  $effect(() => {
    name = application.name;
    redirectUri = application.redirect_uri;
    scopes = application.scopes;
    confidential = application.confidential;
    hcaLogin = application.redirect_to_hca_login;
  });
  const input =
    "w-full px-3 py-2 bg-darkless border border-darkless rounded text-surface-content focus:border-primary focus:ring-1 focus:ring-primary placeholder-secondary";
  const showPath = $derived(
    adminOauthApplications.show.path({ id: application.id }),
  );
</script>

<svelte:head><title>Edit {application.name} - Admin</title></svelte:head>
<div class="max-w-3xl mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">
      Edit Application
    </h1>
    <p class="text-secondary text-lg">
      Update settings for {application.name}
      {#if application.verified}<span
          class="inline-flex items-center gap-1 px-2 py-0.5 bg-green/20 text-green border border-green/30 rounded text-sm ml-1"
          ><PageIcon name="check" class="w-3 h-3" /> Verified</span
        >{/if}
    </p>
  </header>
  <div class="bg-blue/10 border border-blue/30 rounded-lg p-4 mb-6">
    <div class="flex items-start gap-3">
      <PageIcon name="info" class="mt-0.5 h-5 w-5 shrink-0 text-blue" />
      <div>
        <p class="text-blue font-medium">Super Admin Edit</p>
        <p class="text-blue/80 text-sm mt-1">
          As a super admin, you can edit all fields including the name of
          verified applications.
        </p>
      </div>
    </div>
  </div>
  {#if Object.values(errors).flat().length}<div
      class="p-4 bg-red/10 border border-red/20 rounded-lg text-red"
    >
      <span class="font-medium">Error</span>
      <ul class="list-disc list-inside text-red/80 text-sm">
        {#each Object.values(errors).flat() as error}<li>{error}</li>{/each}
      </ul>
    </div>{/if}
  <Form
    action={adminOauthApplications.update.path({ id: application.id })}
    method="patch"
    class="space-y-6"
    ><div class="border border-primary rounded-xl p-6 bg-dark">
      <div class="mb-6 flex items-center gap-3">
        <div class="rounded bg-primary/10 p-2">
          <PageIcon name="monitor" class="h-6 w-6 text-primary" />
        </div>
        <h2 class="text-xl font-semibold text-surface-content">
          Application Details
        </h2>
      </div>
      <div class="space-y-5">
        <label class="block text-sm font-medium text-surface-content"
          >Name<TextInput
            name="oauth_application[name]"
            bind:value={name}
            class={`${input} mt-2`}
            required
            placeholder="My Awesome App"
          />{#if errors.name}<small class="text-red"
              >{errors.name.join(", ")}</small
            >{/if}</label
        >
        <label class="block text-sm font-medium text-surface-content"
          >Redirect URIs<textarea
            name="oauth_application[redirect_uri]"
            bind:value={redirectUri}
            class={`${input} mt-2 font-mono text-sm`}
            rows="3"></textarea></label
        >
        <label class="block text-sm font-medium text-surface-content"
          >Scopes<TextInput
            name="oauth_application[scopes]"
            bind:value={scopes}
            class={`${input} mt-2 font-mono text-sm`}
          /></label
        >
        <CheckboxField
          native
          align="start"
          class="p-4 bg-darkless border border-darkless rounded"
          inputClass="mt-0.5 h-4 w-4 rounded border-darkless bg-darker text-primary focus:ring-primary"
          name="oauth_application[confidential]"
          bind:checked={confidential}
        >
          <span
            ><b class="text-sm text-surface-content">Confidential Application</b
            ><small class="block mt-1 text-secondary"
              >Confidential clients can keep secrets. Native apps and SPAs are
              not confidential.</small
            ></span
          >
        </CheckboxField>
        <CheckboxField
          native
          align="start"
          class="p-4 bg-darkless border border-darkless rounded"
          inputClass="mt-0.5 h-4 w-4 rounded border-darkless bg-darker text-primary focus:ring-primary"
          name="oauth_application[redirect_to_hca_login]"
          bind:checked={hcaLogin}
        >
          <span
            ><b class="text-sm text-surface-content"
              >Use Hack Club Auth for Login</b
            ><small class="block mt-1 text-secondary"
              >Unauthenticated users authorizing this app will be sent directly
              to Hack Club Auth instead of the generic Hackatime sign-in page.</small
            ></span
          >
        </CheckboxField>
      </div>
    </div>
    <div class="flex items-center gap-3">
      <Button
        unstyled
        type="submit"
        class="cursor-pointer rounded bg-primary px-6 py-2 font-medium text-on-primary transition-colors duration-200 hover:opacity-90"
        >Save Changes</Button
      ><Button
        unstyled
        href={showPath}
        class="rounded border border-darkless px-6 py-2 font-medium text-surface-content transition-colors duration-200 hover:bg-darkless"
        >Cancel</Button
      >
    </div></Form
  >
</div>
