<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  type ButtonType = "button" | "submit" | "reset";
  type ButtonSize = "xs" | "sm" | "md" | "lg" | "xl";
  type ButtonVariant =
    | "primary"
    | "surface"
    | "dark"
    | "outlinePrimary";

  let {
    href = "",
    type = "button",
    size = "md",
    variant = "primary",
    unstyled = false,
    class: className = "",
    ...rest
  }: {
    href?: string;
    type?: ButtonType;
    size?: ButtonSize;
    variant?: ButtonVariant;
    unstyled?: boolean;
    class?: string;
    [key: string]: unknown;
  } = $props();

  const sizeClasses: Record<ButtonSize, string> = {
    xs: "px-3 py-1.5 text-xs",
    sm: "px-3 py-2 text-sm",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base",
    xl: "px-8 py-3 text-base",
  };

  const variantClasses: Record<ButtonVariant, string> = {
    primary:
      "bg-primary border border-primary text-on-primary hover:opacity-90",
    surface:
      "bg-surface-100 border border-surface-200 text-surface-content hover:bg-surface-200",
    dark: "bg-dark border border-darkless text-surface-content hover:bg-darkless",
    outlinePrimary: "border border-primary text-primary hover:bg-primary/10",
  };

  const classes = $derived(
    unstyled
      ? className
      : [
          "inline-flex items-center justify-center rounded-lg font-semibold transition-colors duration-200",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40 focus-visible:ring-offset-2 focus-visible:ring-offset-surface",
          "disabled:cursor-not-allowed disabled:opacity-60",
          sizeClasses[size],
          variantClasses[variant],
          className,
        ].join(" "),
  );
</script>

{#if href}
  <Link href={href} class={classes} {...rest}>
    <slot />
  </Link>
{:else}
  <button type={type} class={classes} {...rest}>
    <slot />
  </button>
{/if}
