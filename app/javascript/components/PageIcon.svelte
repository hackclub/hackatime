<script lang="ts">
  type Icon =
    | "arrow-left"
    | "check"
    | "edit"
    | "eye"
    | "info"
    | "key"
    | "link"
    | "monitor"
    | "rotate"
    | "user"
    | "warning";

  let { name, class: className = "" }: { name: Icon; class?: string } =
    $props();

  const paths: Record<Icon, string[]> = {
    "arrow-left": ["M10 19l-7-7m0 0l7-7m-7 7h18"],
    check: ["M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"],
    edit: [
      "M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5",
      "M18.586 2.586a2 2 0 112.828 2.828L11.828 15H9v-2.828l9.586-9.586z",
    ],
    eye: [
      "M15 12a3 3 0 11-6 0 3 3 0 016 0z",
      "M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z",
    ],
    info: ["M12 8h.01", "M11 12h1v4h1", "M21 12a9 9 0 11-18 0 9 9 0 0118 0z"],
    key: [
      "M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z",
    ],
    link: [
      "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101",
      "M10.172 13.828a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1",
    ],
    monitor: [
      "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
    ],
    rotate: [
      "M4 4v5h5",
      "M20 20v-5h-5",
      "M5.5 15a7 7 0 0011.9 2M18.5 9A7 7 0 006.6 7",
    ],
    user: ["M16 7a4 4 0 11-8 0 4 4 0 018 0z", "M5 21a7 7 0 0114 0"],
    warning: [
      "M12 9v2m0 4h.01",
      "M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z",
    ],
  };
</script>

<svg
  class={className}
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  viewBox="0 0 24 24"
  aria-hidden="true"
>
  {#each paths[name] as d}<path
      {d}
      stroke-linecap="round"
      stroke-linejoin="round"
    />{/each}
</svg>
