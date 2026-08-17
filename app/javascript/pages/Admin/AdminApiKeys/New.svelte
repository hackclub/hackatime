<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import TextInput from "../../../components/TextInput.svelte";
  import { adminAdminApiKeys } from "../../../api";
  let { errors }: { errors: string[] } = $props();
</script>

<svelte:head><title>spawn in a new key</title></svelte:head>
<div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
  <div class="mb-8 flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold text-surface-content mb-2">
        spawn in a new key
      </h1>
      <p class="text-muted">its geting real</p>
    </div>
    <Link
      href={adminAdminApiKeys.index.path()}
      class="text-muted hover:text-surface-content">← get me outta here</Link
    >
  </div>
  <div class="bg-dark rounded-lg p-8">
    <Form
      action={adminAdminApiKeys.create.path()}
      method="post"
      class="space-y-6"
      >{#if errors.length}<div
          class="bg-red/50 border border-red rounded-lg p-4"
        >
          <h3 class="text-red font-medium mb-2">
            you done did it, fix this or else
          </h3>
          <ul class="text-red text-sm space-y-1">
            {#each errors as error}<li>• {error}</li>{/each}
          </ul>
        </div>{/if}
      <div>
        <label
          for="key-name"
          class="block text-md font-medium text-surface-content mb-2"
          >Name</label
        ><TextInput
          id="key-name"
          name="admin_api_key[name]"
          placeholder="put down something good please"
          class="w-full px-3 py-2 bg-darkless rounded text-surface-content focus:border-primary focus:ring-1 focus:ring-primary"
        />
      </div>
      <div class="bg-yellow/30 border border-yellow/50 rounded-lg p-4">
        <h3 class="text-yellow font-medium mb-2">
          keep in mind this gives admin access, so dont go sharing it with your
          dog ya goober. we also track whatever you do, so dont go out banning
          people or heidi will pipebomb your sorry butt
        </h3>
      </div>
      <div class="flex justify-end space-x-4">
        <Link
          href={adminAdminApiKeys.index.path()}
          class="px-4 py-2 text-muted hover:text-surface-content"
          >fuck no imma head out</Link
        ><Button
          type="submit"
          class="px-6 py-2 bg-primary hover:bg-red text-on-primary rounded-lg font-medium transition-colors"
          >okay lets do this thing</Button
        >
      </div></Form
    >
  </div>
</div>
