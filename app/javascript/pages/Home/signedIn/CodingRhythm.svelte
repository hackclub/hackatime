<script lang="ts">
  import { fade } from "svelte/transition";
  import { Spring } from "svelte/motion";
  import { secondsToDisplay } from "./utils";

  let {
    data,
  }: {
    data: {
      duration_by_slot: Record<string, number>;
      timezone_label: string;
    };
  } = $props();

  const DAYS = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];
  const LEFT = 64;
  const TOP = 26;
  const CELL = 17;
  const STEP = 22;
  const INTENSITY_CLASSES = [
    "fill-primary/10",
    "fill-primary/15",
    "fill-primary/20",
    "fill-primary/25",
    "fill-primary/30",
    "fill-primary/35",
    "fill-primary/40",
    "fill-primary/45",
    "fill-primary/50",
    "fill-primary/55",
    "fill-primary/60",
    "fill-primary/65",
    "fill-primary/70",
    "fill-primary/75",
    "fill-primary/80",
    "fill-primary/85",
    "fill-primary/90",
    "fill-primary/95",
    "fill-primary",
  ] as const;

  const slots = $derived(
    DAYS.flatMap((day, dayIndex) =>
      Array.from({ length: 24 }, (_, hour) => ({
        day,
        weekday: dayIndex + 1,
        hour,
        seconds: data.duration_by_slot[`${dayIndex + 1}-${hour}`] || 0,
      })),
    ),
  );
  const maxSeconds = $derived(
    Math.max(...slots.map((slot) => slot.seconds), 0),
  );

  let tooltip = $state<{ label: string; x: number; y: number } | null>(null);
  let hideTimer: ReturnType<typeof setTimeout> | undefined;
  const tooltipX = new Spring<number | null>(null);
  const tooltipY = new Spring<number | null>(null);

  $effect(() => {
    if (!tooltip) return;
    tooltipX.set(tooltip.x, { instant: tooltipX.target === null });
    tooltipY.set(tooltip.y, { instant: tooltipY.target === null });
  });

  function hourLabel(hour: number) {
    if (hour === 0) return "12 AM";
    if (hour === 12) return "12 PM";
    return `${hour % 12} ${hour < 12 ? "AM" : "PM"}`;
  }

  function slotLabel(day: string, hour: number, seconds: number) {
    return `${day}, ${hourLabel(hour)}–${hourLabel((hour + 1) % 24)} · ${secondsToDisplay(seconds)}`;
  }

  function intensityClass(seconds: number) {
    if (seconds === 0 || maxSeconds === 0) return "fill-surface-200/35";
    const ratio = seconds / maxSeconds;
    const index = Math.round(
      Math.pow(ratio, 1.25) * (INTENSITY_CLASSES.length - 1),
    );
    return INTENSITY_CLASSES[index];
  }

  function showTooltip(
    slot: (typeof slots)[number],
    event: PointerEvent | FocusEvent,
  ) {
    if (hideTimer) clearTimeout(hideTimer);
    const target = event.currentTarget as SVGRectElement;
    const bounds = target.getBoundingClientRect();
    const pointer = event instanceof PointerEvent;
    tooltip = {
      label: slotLabel(slot.day, slot.hour, slot.seconds),
      x: pointer ? event.clientX + 10 : bounds.left + bounds.width / 2,
      y: pointer ? event.clientY + 10 : bounds.bottom + 8,
    };
  }

  function hideTooltip() {
    hideTimer = setTimeout(() => {
      tooltip = null;
      tooltipX.set(null, { instant: true });
      tooltipY.set(null, { instant: true });
    });
  }
</script>

<section class="rounded-2xl border border-surface-200 bg-dark p-4 sm:p-6">
  <div class="mb-4">
    <h3 class="text-lg font-semibold text-surface-content">Coding Rhythm</h3>
    <p class="text-sm text-surface-content/55">
      When you code, calculated in {data.timezone_label}
    </p>
  </div>

  <div class="overflow-x-auto pb-2">
    <svg
      viewBox="0 0 600 184"
      class="min-w-[600px] w-full"
      role="figure"
      aria-label={`Coding duration by weekday and hour in ${data.timezone_label}`}
    >
      {#each Array.from({ length: 8 }, (_, index) => index * 3) as hour}
        <text
          x={LEFT + hour * STEP + CELL / 2}
          y="12"
          text-anchor="middle"
          class="fill-surface-content/45 text-[9px]"
          >{hourLabel(hour).replace(" ", "")}</text
        >
      {/each}

      {#each DAYS as day, dayIndex}
        <text
          x={LEFT - 8}
          y={TOP + dayIndex * STEP + CELL / 2}
          dominant-baseline="middle"
          text-anchor="end"
          class="fill-surface-content/55 text-[10px]">{day.slice(0, 3)}</text
        >
      {/each}

      {#each slots as slot (`${slot.weekday}-${slot.hour}`)}
        <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
        <rect
          x={LEFT + slot.hour * STEP}
          y={TOP + (slot.weekday - 1) * STEP}
          width={CELL}
          height={CELL}
          rx="3"
          class={`${intensityClass(slot.seconds)} cursor-default outline-none transition-opacity duration-100 hover:opacity-80 focus:stroke-primary focus:stroke-2`}
          role="img"
          tabindex="0"
          aria-label={slotLabel(slot.day, slot.hour, slot.seconds)}
          onpointerenter={(event) => showTooltip(slot, event)}
          onpointermove={(event) => showTooltip(slot, event)}
          onpointerleave={hideTooltip}
          onpointercancel={hideTooltip}
          onfocus={(event) => showTooltip(slot, event)}
          onblur={hideTooltip}
        />
      {/each}
    </svg>
  </div>
</section>

{#if tooltip}
  <div
    role="tooltip"
    class="pointer-events-none fixed z-[1000] rounded-md border border-surface-200 bg-dark/95 px-2.5 py-1.5 text-sm text-surface-content shadow-lg backdrop-blur-sm"
    style:left={`${tooltipX.current ?? tooltip.x}px`}
    style:top={`${tooltipY.current ?? tooltip.y}px`}
    transition:fade={{ duration: 100 }}
  >
    {tooltip.label}
  </div>
{/if}
