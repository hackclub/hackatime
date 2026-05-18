<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import { secondsToDisplay } from "../../../utils";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import MultiSelectCombobox from "../../../components/MultiSelectCombobox.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { GoalsPageProps, ProgrammingGoal } from "./types";
  import { settingsGoals } from "../../../api";

  const MAX_GOALS = 5;
  const QUICK_TARGETS = [
    { label: "15m", seconds: 15 * 60 },
    { label: "30m", seconds: 30 * 60 },
    { label: "1h", seconds: 60 * 60 },
    { label: "2h", seconds: 2 * 60 * 60 },
    { label: "4h", seconds: 4 * 60 * 60 },
  ];

  let {
    active_section,
    page_title,
    heading,
    subheading,
    programming_goals,
    options,
    errors,
    goal_form,
  }: GoalsPageProps = $props();

  // settingsGoals is statically imported below.

  const goals = $derived(programming_goals || []);
  const hasReachedGoalLimit = $derived(goals.length >= MAX_GOALS);
  const activeGoalSummary = $derived(
    `${goals.length} Active Goal${goals.length === 1 ? "" : "s"}`,
  );

  let goalModalOpen = $state(false);
  let editingGoal = $state<ProgrammingGoal | null>(null);
  let targetAmount = $state(30);
  let targetUnit = $state<"minutes" | "hours">("minutes");
  let selectedPeriod = $state<ProgrammingGoal["period"]>("day");
  let selectedLanguages = $state<string[]>([]);
  let selectedProjects = $state<string[]>([]);
  let submitting = $state(false);

  const currentTargetSeconds = $derived(
    Math.round(Number(targetAmount) * (targetUnit === "hours" ? 3600 : 60)),
  );

  const modalErrors = $derived(goal_form?.errors ?? []);

  const unitOptions = [
    { value: "minutes", label: "Minutes" },
    { value: "hours", label: "Hours" },
  ];

  function onRequestSuccess() {
    goalModalOpen = false;
    editingGoal = null;
  }

  // Restore modal state from server on validation error
  $effect(() => {
    selectedPeriod =
      (options.goals.periods[0]?.value as ProgrammingGoal["period"]) || "day";
  });

  $effect(() => {
    goalModalOpen = goal_form?.open ?? false;
    if (!goal_form?.open) return;

    const seconds = goal_form.target_seconds || 1800;
    const unit = seconds % 3600 === 0 ? "hours" : "minutes";
    selectedPeriod = (goal_form.period as ProgrammingGoal["period"]) || "day";
    targetUnit = unit;
    targetAmount = unit === "hours" ? seconds / 3600 : seconds / 60;
    selectedLanguages = goal_form.languages || [];
    selectedProjects = goal_form.projects || [];

    if (goal_form.mode === "edit" && goal_form.goal_id) {
      editingGoal =
        (programming_goals || []).find((g) => g.id === goal_form.goal_id) ??
        null;
    }
  });

  function formatPeriod(period: ProgrammingGoal["period"]) {
    if (period === "day") return "Daily";
    if (period === "week") return "Weekly";
    return "Monthly";
  }

  function scopeSubtitle(goal: ProgrammingGoal) {
    const parts = [];
    if (goal.languages.length > 0)
      parts.push(`Languages: ${goal.languages.join(", ")}`);
    if (goal.projects.length > 0)
      parts.push(`Projects: ${goal.projects.join(", ")}`);
    return parts.join(" AND ") || "All programming activity";
  }

  function resetBuilder() {
    const defaultSeconds = options.goals.preset_target_seconds[0] || 1800;
    selectedPeriod =
      (options.goals.periods[0]?.value as ProgrammingGoal["period"]) || "day";
    targetUnit = defaultSeconds % 3600 === 0 ? "hours" : "minutes";
    targetAmount =
      targetUnit === "hours" ? defaultSeconds / 3600 : defaultSeconds / 60;
    selectedLanguages = [];
    selectedProjects = [];
  }

  function openCreateModal() {
    editingGoal = null;
    resetBuilder();
    goalModalOpen = true;
  }

  function openEditModal(goal: ProgrammingGoal) {
    editingGoal = goal;
    selectedPeriod = goal.period;
    targetUnit = goal.target_seconds % 3600 === 0 ? "hours" : "minutes";
    targetAmount =
      targetUnit === "hours"
        ? goal.target_seconds / 3600
        : goal.target_seconds / 60;
    selectedLanguages = [...goal.languages];
    selectedProjects = [...goal.projects];
    goalModalOpen = true;
  }

  function applyQuickTarget(seconds: number) {
    if (seconds % 3600 === 0) {
      targetUnit = "hours";
      targetAmount = seconds / 3600;
    } else {
      targetUnit = "minutes";
      targetAmount = seconds / 60;
    }
  }

  function goalData() {
    return {
      goal: {
        period: selectedPeriod,
        target_seconds: currentTargetSeconds,
        languages: selectedLanguages,
        projects: selectedProjects,
      },
    };
  }

  function saveGoal() {
    if (submitting) return;
    submitting = true;

    const callbacks = {
      preserveScroll: true,
      onSuccess: onRequestSuccess,
      onFinish: () => {
        submitting = false;
      },
    };

    if (editingGoal) {
      router.patch(
        settingsGoals.update.path({ goalId: editingGoal.id }),
        goalData(),
        callbacks,
      );
    } else {
      router.post(settingsGoals.create.path(), goalData(), callbacks);
    }
  }

  function deleteGoal(goal: ProgrammingGoal) {
    if (submitting) return;
    submitting = true;

    router.delete(settingsGoals.destroy.path({ goalId: goal.id }), {
      preserveScroll: true,
      onSuccess: onRequestSuccess,
      onFinish: () => {
        submitting = false;
      },
    });
  }
</script>

<svelte:head>
  <title>Goals - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_programming_goals"
    title="Programming Goals"
    description={`Set up to ${MAX_GOALS} goals for your daily, weekly, or monthly coding targets.`}
    footerClass="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
  >
    <div class="flex items-center justify-between gap-3">
      <p
        class="text-xs font-semibold uppercase tracking-wider text-secondary/80 sm:text-sm"
      >
        {activeGoalSummary}
      </p>
    </div>

    {#if goals.length === 0}
      <div
        class="mt-4 rounded-md border border-surface-200 bg-darker/30 px-4 py-5 text-center"
      >
        <p class="text-sm text-muted">
          Set a goal to track your coding consistency.
        </p>
      </div>
    {:else}
      <div
        class="mt-4 overflow-hidden rounded-md border border-surface-200 bg-darker/30"
      >
        {#each goals as goal (goal.id)}
          <article
            class="flex flex-wrap items-start justify-between gap-3 border-b border-surface-200 px-4 py-3 last:border-b-0"
          >
            <div class="min-w-0">
              <p class="text-sm font-semibold text-surface-content">
                {formatPeriod(goal.period)}: {secondsToDisplay(
                  goal.target_seconds,
                )}
              </p>
              <p class="mt-1 truncate text-xs text-muted">
                {scopeSubtitle(goal)}
              </p>
            </div>

            <div class="flex items-center gap-2">
              <Button
                type="button"
                variant="surface"
                size="xs"
                class="rounded-md"
                onclick={() => openEditModal(goal)}
                disabled={submitting}
              >
                Edit
              </Button>
              <Button
                type="button"
                variant="surface"
                size="xs"
                class="rounded-md"
                onclick={() => deleteGoal(goal)}
                disabled={submitting}
              >
                Delete
              </Button>
            </div>
          </article>
        {/each}
      </div>
    {/if}

    {#snippet footer()}
      <p class="text-sm text-muted">
        {#if hasReachedGoalLimit}
          Goal limit reached. Delete an existing goal before adding another.
        {:else}
          Add a goal to stay accountable across languages and projects.
        {/if}
      </p>
      <Button
        type="button"
        variant="primary"
        class="rounded-md px-3 py-2"
        onclick={openCreateModal}
        disabled={hasReachedGoalLimit || submitting}
      >
        New goal
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>

<Modal
  bind:open={goalModalOpen}
  title={editingGoal ? "Edit target" : "Set a new target"}
  maxWidth="max-w-2xl"
  bodyClass="mb-6"
  hasBody
  hasActions
>
  {#snippet body()}
    <div class="space-y-4">
      <div
        class="grid grid-cols-1 gap-3 sm:grid-cols-[auto_auto_auto_auto] sm:items-center"
      >
        <span class="text-sm text-surface-content">I want to code for</span>
        <input
          type="number"
          min="1"
          step="1"
          bind:value={targetAmount}
          class="w-24 rounded-md border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
        />
        <Select
          id="goal_target_unit"
          bind:value={targetUnit}
          items={unitOptions}
        />
        <div class="flex items-center gap-2">
          <span class="text-sm text-muted">per</span>
          <Select
            id="goal_period"
            bind:value={selectedPeriod}
            items={options.goals.periods}
          />
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        {#each QUICK_TARGETS as quickTarget}
          {@const isActive = quickTarget.seconds === currentTargetSeconds}
          <Button
            type="button"
            variant={isActive ? "primary" : "surface"}
            size="xs"
            class={isActive
              ? "rounded-full ring-2 ring-primary/40 ring-offset-1 ring-offset-surface"
              : "rounded-full"}
            onclick={() => applyQuickTarget(quickTarget.seconds)}
          >
            {quickTarget.label}
          </Button>
        {/each}
      </div>

      <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
        <MultiSelectCombobox
          label="Languages (optional)"
          placeholder="Filter by language..."
          emptyText="No languages found"
          options={options.goals.selectable_languages}
          bind:selected={selectedLanguages}
        />

        <MultiSelectCombobox
          label="Projects (optional)"
          placeholder="Filter by project..."
          emptyText="No projects found"
          options={options.goals.selectable_projects}
          bind:selected={selectedProjects}
        />
      </div>

      {#if modalErrors.length > 0}
        <p
          class="rounded-md border border-red/40 bg-red/10 px-3 py-2 text-xs text-red"
        >
          {modalErrors.join(", ")}
        </p>
      {/if}
    </div>
  {/snippet}

  {#snippet actions()}
    <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
      <Button
        type="button"
        variant="dark"
        class="h-10 rounded-md border border-surface-300 text-muted"
        onclick={() => (goalModalOpen = false)}
      >
        Cancel
      </Button>
      <Button
        type="button"
        variant="primary"
        class="h-10 rounded-md"
        onclick={saveGoal}
        disabled={submitting}
      >
        {submitting ? "Saving..." : editingGoal ? "Update Goal" : "Create Goal"}
      </Button>
    </div>
  {/snippet}
</Modal>
