<script lang="ts">
  let {
    value = $bindable(),
    loading,
    onsubmit,
  }: {
    value: string;
    loading: boolean;
    onsubmit: () => void;
  } = $props();
</script>

<form
  class="key-form"
  onsubmit={(event) => {
    event.preventDefault();
    onsubmit();
  }}
>
  <label for="api-key">API key</label>
  <div class="key-row">
    <input
      id="api-key"
      name="api-key"
      type="password"
      autocomplete="off"
      placeholder="dev-api-key-12345"
      bind:value
    />
    <button
      class="button primary"
      type="submit"
      disabled={loading || value.length === 0}
    >
      {loading ? "Loading" : "Open dashboard"}
    </button>
  </div>
</form>
