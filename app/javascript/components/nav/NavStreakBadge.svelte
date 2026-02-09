<script lang="ts">
  type NavStreak = {
    count: number;
    display: string;
    title: string;
    show_text?: boolean;
    icon_size?: number;
    show_super_class?: boolean;
  };

  let { streak }: { streak: NavStreak } = $props();

  const streakClasses = (count: number) => {
    if (count >= 30) {
      return {
        bg: "from-blue-900/20 to-indigo-900/20",
        hbg: "hover:from-blue-800/30 hover:to-indigo-800/30",
        bc: "border-blue-700",
        ic: "text-blue-400 group-hover:text-blue-300",
        tc: "text-blue-300 group-hover:text-blue-200",
        tm: "text-blue-400",
      };
    }
    if (count >= 7) {
      return {
        bg: "from-red-900/20 to-orange-900/20",
        hbg: "hover:from-red-800/30 hover:to-orange-800/30",
        bc: "border-red-700",
        ic: "text-red-400 group-hover:text-red-300",
        tc: "text-red-300 group-hover:text-red-200",
        tm: "text-red-400",
      };
    }
    return {
      bg: "from-orange-900/20 to-yellow-900/20",
      hbg: "hover:from-orange-800/30 hover:to-yellow-800/30",
      bc: "border-orange-700",
      ic: "text-orange-400 group-hover:text-orange-300",
      tc: "text-orange-300 group-hover:text-orange-200",
      tm: "text-orange-400",
    };
  };
</script>

{#if streak?.count > 0}
  {@const styles = streakClasses(streak.count)}
  {@const showText = streak.show_text ?? false}
  {@const iconSize = streak.icon_size ?? 24}
  {@const superClass = streak.show_super_class ? "super" : ""}
  <div
    class={`inline-flex items-center gap-1 px-2 py-1 bg-gradient-to-r ${styles.bg} border ${styles.bc} rounded-lg transition-all duration-200 ${styles.hbg} group ${superClass}`}
    title={streak.title}
  >
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={iconSize}
      height={iconSize}
      viewBox="0 0 24 24"
      class={`${styles.ic} transition-colors duration-200 group-hover:animate-pulse`}
    >
      <path
        fill="currentColor"
        d="M10 2c0-.88 1.056-1.331 1.692-.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08.174l.012.003c.625.133 1.203-.43 2.303-2.173l.14-.224a1 1 0 0 1 1.582-.153C18.733 9.46 20 12.402 20 14.295C20 18.56 16.409 22 12 22s-8-3.44-8-7.706c0-2.252 1.022-4.716 2.632-6.301l.605-.589c.241-.236.434-.43.618-.624C9.285 5.268 10 3.856 10 2"
      />
    </svg>

    <span
      class={`text-md font-semibold ${styles.tc} transition-colors duration-200`}
    >
      {streak.display}
      {#if showText}
        <span class={`ml-1 font-normal ${styles.tm}`}>day streak</span>
      {/if}
    </span>
  </div>
{/if}
