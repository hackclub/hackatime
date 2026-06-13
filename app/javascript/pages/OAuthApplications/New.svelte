<script lang="ts">
  import FormPage from "./components/FormPage.svelte";
  import type { OAuthApplicationFormProps } from "./types";

  let props: OAuthApplicationFormProps = $props();
</script>

<FormPage {...props} />
