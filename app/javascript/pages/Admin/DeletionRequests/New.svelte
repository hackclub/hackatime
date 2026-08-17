<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import TextInput from "../../../components/TextInput.svelte";
  import { adminDeletionRequests } from "../../../api";
</script>

<svelte:head><title>delete account</title></svelte:head>
<div class="max-w-lg mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">delete account</h1>
    <p class="text-muted text-sm">
      look up a user to create a deletion request
    </p>
  </header>
  <div class="border border-primary rounded-xl p-6 bg-dark">
    <Form action={adminDeletionRequests.confirm.path()} method="get"
      ><div class="space-y-4">
        <div>
          <label for="q" class="block text-sm text-muted mb-1"
            >user ID, username, email, or Slack UID</label
          ><TextInput
            id="q"
            name="q"
            class="w-full bg-surface border border-surface-200 rounded-lg px-3 py-2 text-surface-content focus:outline-none focus:border-primary"
          />
        </div>
        <Button
          type="submit"
          class="w-full px-4 py-2 bg-primary hover:bg-primary text-on-primary font-medium rounded-lg transition-colors"
          >look up</Button
        >
      </div></Form
    >
  </div>
  <div class="text-center">
    <Link
      href={adminDeletionRequests.index.path()}
      class="text-sm text-muted hover:text-surface-content"
      >back to deletion requests</Link
    >
  </div>
</div>
