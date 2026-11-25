<script lang="ts" module>
  export type UserSearchComboboxState<Result> = {
    query: string;
    results: Result[];
    open: boolean;
    highlight: number;
    searching: boolean;
    searchError: boolean;
    listboxId: string;
    activeDescendant: string | undefined;
    setQuery: (query: string) => void;
    select: (result: Result) => void;
    selectFirstResult: () => void;
    handleKeydown: (event: KeyboardEvent) => void;
    handleOptionKeydown: (event: KeyboardEvent, result: Result) => void;
    openResults: () => void;
    closeResults: () => void;
  };
</script>

<script lang="ts" generics="Result extends { id: number }">
  import { onDestroy, type Snippet } from "svelte";
  import { Debounced } from "runed";

  let {
    searchUrl,
    id,
    onselect,
    searchWhen = (query: string) => query.length > 0,
    children,
  }: {
    searchUrl: string;
    id: string;
    onselect: (result: Result) => void;
    searchWhen?: (query: string) => boolean;
    children: Snippet<[UserSearchComboboxState<Result>]>;
  } = $props();

  let query = $state("");
  let results = $state<Result[]>([]);
  let open = $state(false);
  let highlight = $state(-1);
  let searching = $state(false);
  let searchError = $state(false);
  let searchAbortController: AbortController | null = null;
  let searchSequence = 0;
  let selectFirstWhenResultsAvailable = false;
  const debouncedQuery = new Debounced(() => query, 200);

  const listboxId = $derived(`${id}-results`);
  const activeDescendant = $derived(
    open && highlight >= 0 && highlight < results.length
      ? `${id}-result-${results[highlight].id}`
      : undefined,
  );

  $effect(() => {
    void search(debouncedQuery.current);
  });

  onDestroy(() => searchAbortController?.abort());

  function invalidateSearch() {
    searchSequence += 1;
    searchAbortController?.abort();
    searchAbortController = null;
    searching = false;
  }

  function resetResults() {
    open = false;
    results = [];
    highlight = -1;
    searchError = false;
    selectFirstWhenResultsAvailable = false;
  }

  function setQuery(nextQuery: string) {
    query = nextQuery;
    invalidateSearch();
    selectFirstWhenResultsAvailable = false;

    if (!searchWhen(nextQuery.trim())) resetResults();
  }

  async function search(searchQuery: string) {
    const trimmed = searchQuery.trim();
    if (!searchWhen(trimmed)) return resetResults();

    const requestSequence = ++searchSequence;
    searchAbortController?.abort();
    const controller = new AbortController();
    searchAbortController = controller;
    searching = true;
    searchError = false;

    try {
      const separator = searchUrl.includes("?") ? "&" : "?";
      const response = await fetch(
        `${searchUrl}${separator}query=${encodeURIComponent(trimmed)}`,
        { signal: controller.signal },
      );
      if (!response.ok)
        throw new Error(`Search failed with ${response.status}`);

      const nextResults: Result[] = await response.json();
      if (requestSequence !== searchSequence) return;

      results = nextResults;
      if (selectFirstWhenResultsAvailable) {
        selectFirstWhenResultsAvailable = false;
        if (nextResults[0]) return select(nextResults[0]);
      }
      open = true;
      highlight = -1;
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return;
      if (requestSequence !== searchSequence) return;

      results = [];
      open = true;
      highlight = -1;
      searchError = true;
      selectFirstWhenResultsAvailable = false;
    } finally {
      if (requestSequence === searchSequence) searching = false;
      if (searchAbortController === controller) searchAbortController = null;
    }
  }

  function select(result: Result) {
    onselect(result);
    query = "";
    invalidateSearch();
    resetResults();
  }

  function selectFirstResult() {
    if (open && results[0]) return select(results[0]);
    if (!searchWhen(query.trim())) return;

    selectFirstWhenResultsAvailable = true;
    if (debouncedQuery.pending) {
      debouncedQuery.cancel();
      void search(query);
    }
  }

  function handleOptionKeydown(event: KeyboardEvent, result: Result) {
    if (event.key !== "Enter" && event.key !== " ") return;

    event.preventDefault();
    select(result);
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === "Escape") {
      closeResults();
      return;
    }

    if (
      event.key !== "ArrowDown" &&
      event.key !== "ArrowUp" &&
      event.key !== "Enter"
    )
      return;

    event.preventDefault();

    if (event.key === "ArrowDown")
      highlight = Math.min(highlight + 1, results.length - 1);
    else if (event.key === "ArrowUp") highlight = Math.max(highlight - 1, 0);
    else if (highlight >= 0 && highlight < results.length)
      select(results[highlight]);
  }

  function openResults() {
    if (results.length || searchError) open = true;
  }

  function closeResults() {
    debouncedQuery.cancel();
    invalidateSearch();
    selectFirstWhenResultsAvailable = false;
    open = false;
  }
</script>

{@render children({
  query,
  results,
  open,
  highlight,
  searching,
  searchError,
  listboxId,
  activeDescendant,
  setQuery,
  select,
  selectFirstResult,
  handleKeydown,
  handleOptionKeydown,
  openResults,
  closeResults,
})}
