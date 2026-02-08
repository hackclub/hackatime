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
</script>

<p>
  {#if show_logged_time_sentence}
    You've logged
    {todays_duration_display}
    {#if todays_languages.length > 0 || todays_editors.length > 0}
      across
      {#if todays_languages.length > 0}
        {#if todays_languages.length >= 4}
          {todays_languages.slice(0, 2).join(", ")}
          <span title={todays_languages.slice(2).join(", ")}>
            (& {todays_languages.length - 2}
            {pluralize(
              todays_languages.length - 2,
              "other language",
              "other languages",
            )})
          </span>
        {:else}
          {toSentence(todays_languages)}
        {/if}
      {/if}
      {#if todays_languages.length > 0 && todays_editors.length > 0}
        using
      {/if}
      {#if todays_editors.length > 0}
        {toSentence(todays_editors)}
      {/if}
    {/if}
  {:else}
    No time logged today... but you can change that!
  {/if}
</p>
