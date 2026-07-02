import { cubicOut } from "svelte/easing";

export function popIn(_node: HTMLElement, { duration = 220 } = {}) {
  const reduce =
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduce) return { duration: 0 };

  return {
    duration,
    easing: cubicOut,
    css: (t: number) =>
      `opacity: ${t}; transform: scale(${0.98 + 0.02 * t}) translateY(${(1 - t) * 8}px)`,
  };
}
