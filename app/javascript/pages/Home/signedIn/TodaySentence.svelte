<script lang="ts">
  import { pluralize, toSentence } from "./utils";

  let {
    show_logged_time_sentence,
    todays_duration_display,
    todays_languages,
    todays_editors,
  }: {
    show_logged_time_sentence: boolean;
    todays_duration_display: string;
    todays_languages: string[];
    todays_editors: string[];
  } = $props();

  const langs = $derived(todays_languages);
  const editors = $derived(todays_editors);
</script>

<p>
  {#if show_logged_time_sentence}
    Today, you've logged
    {todays_duration_display}
    {#if langs.length || editors.length}
      across
      {#if langs.length >= 4}
        {langs.slice(0, 2).join(", ")}
        <span title={langs.slice(2).join(", ")}>
          (& {langs.length - 2}
          {pluralize(langs.length - 2, "other language", "other languages")})
        </span>
      {:else if langs.length > 0}
        {toSentence(langs)}
      {/if}
      {#if langs.length > 0 && editors.length > 0}using{/if}
      {#if editors.length > 0}{toSentence(editors)}{/if}
    {/if}
  {:else}
    No time logged today... but you can change that!
  {/if}
</p>
