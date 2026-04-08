<script lang="ts">
  import type { LinkComponentBaseProps } from "@inertiajs/core";
  import { Link as InertiaLink } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";

  type LinkMethod = NonNullable<LinkComponentBaseProps["method"]>;
  type LinkHref = LinkComponentBaseProps["href"];
  type LinkPrefetch = LinkComponentBaseProps["prefetch"];

  type Props = {
    href?: LinkHref;
    method?: LinkMethod;
    prefetch?: LinkPrefetch;
    children?: Snippet;
    [key: string]: unknown;
  };

  const inferredMethod = (href?: LinkHref, method?: LinkMethod): LinkMethod => {
    if (method) {
      return method;
    }

    if (href && typeof href === "object" && "method" in href) {
      return href.method;
    }

    return "get";
  };

  let { href, method, prefetch, children, ...rest }: Props = $props();

  const resolvedPrefetch = $derived(
    prefetch ?? inferredMethod(href, method) === "get",
  );
</script>

<InertiaLink {href} {method} prefetch={resolvedPrefetch} {...rest}>
  {@render children?.()}
</InertiaLink>
