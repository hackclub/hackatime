<script module lang="ts">
  import settingsLayout from "./layout";
  export const layout = settingsLayout;
</script>

<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { secondsToDisplay } from "../../../utils";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import MultiSelectCombobox from "../../../components/MultiSelectCombobox.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import { settingsGoals } from "../../../api";

  type ProgrammingGoal = {
    id: string;
    period: "day" | "week" | "month";
    target_seconds: number;
    languages: string[];
    projects: string[];
  };

  type Props = {
    programming_goals: ProgrammingGoal[];
    options: {
      goals: {
        periods: Array<{ label: string; value: string }>;
        preset_target_seconds: number[];
        selectable_languages: Array<{ label: string; value: string }>;
        selectable_projects: Array<{ label: string; value: string }>;
      };
    };
    goal_form?: {
      open: boolean;
      mode: "create" | "edit";
      goal_id: string | null;
      period: string;
      target_seconds: number;
      languages: string[];
      projects: string[];
      errors: string[];
    } | null;
  };

  const MAX_GOALS = 5;
  const QUICK_TARGETS = [
    { label: "15m", seconds: 900 },
    { label: "30m", seconds: 1800 },
    { label: "1h", seconds: 3600 },
    { label: "2h", seconds: 7200 },
    { label: "4h", seconds: 14400 },
  ];
  const UNIT_OPTIONS = [
    { value: "minutes", label: "Minutes" },
    { value: "hours", label: "Hours" },
  ];
  const PERIOD_LABELS: Record<ProgrammingGoal["period"], string> = {
    day: "Daily",
    week: "Weekly",
    month: "Monthly",
  };

  let { programming_goals, options, goal_form }: Props = $props();

  const goals = $derived(programming_goals || []);
  const hasReachedGoalLimit = $derived(goals.length >= MAX_GOALS);

  const defaultPeriod = () =>
    (options.goals.periods[0]?.value as ProgrammingGoal["period"]) || "day";

  let goalModalOpen = $state(false);
  let editingGoal = $state<ProgrammingGoal | null>(null);
  let targetAmount = $state(30);
  let targetUnit = $state<"minutes" | "hours">("minutes");
  let selectedPeriod = $state<ProgrammingGoal["period"]>(defaultPeriod());
  let selectedLanguages = $state<string[]>([]);
  let selectedProjects = $state<string[]>([]);

  $effect(() => {
    goalModalOpen = goal_form?.open ?? false;
    if (!goal_form?.open) return;
    selectedPeriod =
      (goal_form.period as ProgrammingGoal["period"]) || defaultPeriod();
    setFromSeconds(goal_form.target_seconds || 1800);
    selectedLanguages = goal_form.languages || [];
    selectedProjects = goal_form.projects || [];
    editingGoal =
      goal_form.mode === "edit" && goal_form.goal_id
        ? ((programming_goals || []).find((g) => g.id === goal_form.goal_id) ??
          null)
        : null;
  });

  const currentTargetSeconds = $derived(
    Math.round(Number(targetAmount) * (targetUnit === "hours" ? 3600 : 60)),
  );
  const modalErrors = $derived(goal_form?.errors ?? []);

  function scopeSubtitle(goal: ProgrammingGoal) {
    const parts = [];
    if (goal.languages.length > 0)
      parts.push(`Languages: ${goal.languages.join(", ")}`);
    if (goal.projects.length > 0)
      parts.push(`Projects: ${goal.projects.join(", ")}`);
    return parts.join(" AND ") || "All programming activity";
  }

  function setFromSeconds(seconds: number) {
    targetUnit = seconds % 3600 === 0 ? "hours" : "minutes";
    targetAmount = targetUnit === "hours" ? seconds / 3600 : seconds / 60;
  }

  function openCreateModal() {
    editingGoal = null;
    selectedPeriod = defaultPeriod();
    setFromSeconds(options.goals.preset_target_seconds[0] || 1800);
    selectedLanguages = [];
    selectedProjects = [];
    goalModalOpen = true;
  }

  function openEditModal(goal: ProgrammingGoal) {
    editingGoal = goal;
    selectedPeriod = goal.period;
    setFromSeconds(goal.target_seconds);
    selectedLanguages = [...goal.languages];
    selectedProjects = [...goal.projects];
    goalModalOpen = true;
  }

  function closeGoalModal() {
    goalModalOpen = false;
    editingGoal = null;
  }
</script>

<svelte:head>
  <title>Goals - Hackatime Settings</title>
</svelte:head>

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
      {goals.length} Active Goal{goals.length === 1 ? "" : "s"}
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
              {PERIOD_LABELS[goal.period]}: {secondsToDisplay(
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
            >
              Edit
            </Button>
            <Form
              action={settingsGoals.destroy.path({ goalId: goal.id })}
              method="delete"
              options={{ preserveScroll: true }}
            >
              {#snippet children({ processing })}
                <Button
                  type="submit"
                  variant="surface"
                  size="xs"
                  class="rounded-md"
                  disabled={processing}
                >
                  {processing ? "Deleting..." : "Delete"}
                </Button>
              {/snippet}
            </Form>
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
      disabled={hasReachedGoalLimit}
    >
      New goal
    </Button>
  {/snippet}
</SectionCard>

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
          items={UNIT_OPTIONS}
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
        {#each QUICK_TARGETS as q}
          {@const isActive = q.seconds === currentTargetSeconds}
          <Button
            type="button"
            variant={isActive ? "primary" : "surface"}
            size="xs"
            class={isActive
              ? "rounded-full ring-2 ring-primary/40 ring-offset-1 ring-offset-surface"
              : "rounded-full"}
            onclick={() => setFromSeconds(q.seconds)}
          >
            {q.label}
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
    <Form
      action={editingGoal
        ? settingsGoals.update.path({ goalId: editingGoal.id })
        : settingsGoals.create.path()}
      method={editingGoal ? "patch" : "post"}
      options={{ preserveScroll: true }}
      onSuccess={closeGoalModal}
    >
      {#snippet children({ processing })}
        <input type="hidden" name="goal[period]" value={selectedPeriod} />
        <input
          type="hidden"
          name="goal[target_seconds]"
          value={currentTargetSeconds}
        />
        <input type="hidden" name="goal[languages][]" value="" />
        {#each selectedLanguages as language}
          <input type="hidden" name="goal[languages][]" value={language} />
        {/each}
        <input type="hidden" name="goal[projects][]" value="" />
        {#each selectedProjects as project}
          <input type="hidden" name="goal[projects][]" value={project} />
        {/each}

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
            type="submit"
            variant="primary"
            class="h-10 rounded-md"
            disabled={processing}
          >
            {processing
              ? "Saving..."
              : editingGoal
                ? "Update Goal"
                : "Create Goal"}
          </Button>
        </div>
      {/snippet}
    </Form>
  {/snippet}
</Modal>
