<script module>
  export const layout = false;
</script>

<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";

  interface Props {
    page_title: string;
    create_heartbeat_import_path: string;
    data_settings_path: string;
  }

  let { page_title, create_heartbeat_import_path, data_settings_path }: Props =
    $props();

  let downloadUrl = $state("");
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="flex min-h-screen w-screen items-center justify-center p-4">
  <div
    class="w-full max-w-2xl rounded-2xl border border-surface-200 bg-dark p-6 shadow-xl"
  >
    <div class="space-y-3">
      <h1 class="text-3xl font-bold text-surface-content">
        Paste your WakaTime export link
      </h1>
      <p class="text-sm leading-6 text-muted">
        WakaTime only allows a fresh export request once every 7 days. Open
        <a
          href="https://wakatime.com/settings/account"
          target="_blank"
          rel="noreferrer"
          class="text-primary underline underline-offset-2"
        >
          https://wakatime.com/settings/account
        </a>, find the latest export, right click <strong>Download</strong>,
        choose
        <strong>Copy link</strong>, then paste that URL below.
      </p>
    </div>

    <Form
      method="post"
      action={create_heartbeat_import_path}
      class="mt-6 space-y-4"
    >
      {#snippet children({ processing })}
        <label class="block space-y-2" for="wakatime_download_url">
          <span class="text-sm font-medium text-surface-content">
            Download link
          </span>
          <input
            id="wakatime_download_url"
            name="heartbeat_import[download_url]"
            type="url"
            bind:value={downloadUrl}
            placeholder="https://wakatime.s3.amazonaws.com/..."
            required
            disabled={processing}
            class="w-full rounded-lg border border-surface-200 bg-input px-4 py-3 text-sm text-surface-content focus:border-primary focus:outline-none disabled:cursor-not-allowed disabled:opacity-60"
          />
        </label>

        <div class="flex flex-col gap-3 sm:flex-row">
          <Button
            type="submit"
            variant="primary"
            size="lg"
            disabled={!downloadUrl.trim() || processing}
          >
            {processing ? "Starting import..." : "Start import"}
          </Button>
          <Button href={data_settings_path} variant="surface" size="lg">
            Back to data settings
          </Button>
        </div>
      {/snippet}
    </Form>
  </div>
</div>
