import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-context";

interface Habit {
  id: string;
  name: string;
  created_at: string;
}

interface HabitCompletion {
  id: string;
  habit_id: string;
  completed_date: string;
}

export function HabitTrackerWidget() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [newHabitName, setNewHabitName] = useState("");
  const [isAdding, setIsAdding] = useState(false);

  const today = new Date().toISOString().split("T")[0];

  // Fetch habits
  const habitsQuery = useQuery({
    queryKey: ["habits", user?.id],
    queryFn: async () => {
      if (!user) return [];
      const { data, error } = await supabase
        .from("habits")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: true });
      if (error) throw error;
      return data as Habit[];
    },
    enabled: !!user,
  });

  // Fetch today's completions
  const completionsQuery = useQuery({
    queryKey: ["habit-completions", user?.id, today],
    queryFn: async () => {
      if (!user) return [];
      const { data, error } = await supabase
        .from("habit_completions")
        .select("*")
        .eq("user_id", user.id)
        .eq("completed_date", today);
      if (error) throw error;
      return data as HabitCompletion[];
    },
    enabled: !!user,
  });

  // Toggle habit completion
  const toggleMutation = useMutation({
    mutationFn: async ({
      habitId,
      isCompleted,
    }: {
      habitId: string;
      isCompleted: boolean;
    }) => {
      if (!user) throw new Error("Not authenticated");

      if (isCompleted) {
        const { error } = await supabase
          .from("habit_completions")
          .delete()
          .eq("habit_id", habitId)
          .eq("completed_date", today);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("habit_completions").insert({
          habit_id: habitId,
          user_id: user.id,
          completed_date: today,
        });
        if (error) throw error;
      }
    },
    onMutate: async ({
      habitId,
      isCompleted,
    }: {
      habitId: string;
      isCompleted: boolean;
    }) => {
      await queryClient.cancelQueries({
        queryKey: ["habit-completions", user?.id, today],
      });

      const previousCompletions = queryClient.getQueryData<HabitCompletion[]>([
        "habit-completions",
        user?.id,
        today,
      ]);

      queryClient.setQueryData<HabitCompletion[]>(
        ["habit-completions", user?.id, today],
        (old = []) => {
          if (isCompleted) {
            return old.filter((c: HabitCompletion) => c.habit_id !== habitId);
          } else {
            return [
              ...old,
              {
                id: `temp-${habitId}`,
                habit_id: habitId,
                completed_date: today,
              },
            ];
          }
        },
      );

      return { previousCompletions };
    },
    onError: (
      _err: unknown,
      _variables: unknown,
      context: { previousCompletions?: HabitCompletion[] } | undefined,
    ) => {
      if (context?.previousCompletions) {
        queryClient.setQueryData(
          ["habit-completions", user?.id, today],
          context.previousCompletions,
        );
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({
        queryKey: ["habit-completions", user?.id, today],
      });
    },
  });

  // Add new habit
  const addHabitMutation = useMutation({
    mutationFn: async (name: string) => {
      if (!user) throw new Error("Not authenticated");
      const { data, error } = await supabase
        .from("habits")
        .insert({ user_id: user.id, name })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["habits", user?.id] });
      setNewHabitName("");
      setIsAdding(false);
    },
  });

  const habits = habitsQuery.data ?? [];
  const completions = completionsQuery.data ?? [];
  const completedIds = new Set(
    completions.map((c: HabitCompletion) => c.habit_id),
  );
  const completedCount = completedIds.size;

  const handleToggle = (habitId: string) => {
    const isCompleted = completedIds.has(habitId);
    toggleMutation.mutate({ habitId, isCompleted });
  };

  const handleAddHabit = () => {
    if (newHabitName.trim()) {
      addHabitMutation.mutate(newHabitName.trim());
    }
  };

  return (
    <article className="card">
      <div className="card-header">
        <h3>Habit Tracker</h3>
        <button
          type="button"
          onClick={() => setIsAdding(!isAdding)}
          style={{
            background: "none",
            border: "none",
            fontSize: "1.5rem",
            cursor: "pointer",
            padding: "0",
            lineHeight: "1",
          }}
          title="Add habit"
        >
          +
        </button>
      </div>
      <div className="card-content">
        {isAdding && (
          <div style={{ marginBottom: "1rem", display: "flex", gap: "0.5rem" }}>
            <input
              type="text"
              value={newHabitName}
              onChange={(e) => setNewHabitName(e.target.value)}
              placeholder="New habit name"
              onKeyDown={(e) => {
                if (e.key === "Enter") handleAddHabit();
                if (e.key === "Escape") {
                  setIsAdding(false);
                  setNewHabitName("");
                }
              }}
              autoFocus
              style={{
                flex: 1,
                padding: "0.5rem",
                border: "1px solid #ddd",
                borderRadius: "4px",
              }}
            />
            <button
              type="button"
              onClick={handleAddHabit}
              disabled={!newHabitName.trim() || addHabitMutation.isPending}
              style={{ padding: "0.5rem 1rem" }}
            >
              Add
            </button>
          </div>
        )}

        {habitsQuery.isLoading && <p className="muted">Loading habits…</p>}

        {habits.length === 0 && !habitsQuery.isLoading && (
          <p className="muted">No habits yet. Click + to add one.</p>
        )}

        {habits.length > 0 && (
          <>
            <div style={{ marginBottom: "1rem" }}>
              <p className="muted">
                {completedCount} / {habits.length} habits done today
              </p>
            </div>
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "0.5rem",
              }}
            >
              {habits.map((habit: Habit) => {
                const isCompleted = completedIds.has(habit.id);
                return (
                  <label
                    key={habit.id}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "0.75rem",
                      cursor: "pointer",
                      padding: "0.5rem",
                      borderRadius: "4px",
                      transition: "background 0.2s",
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = "#f5f5f5";
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = "transparent";
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={isCompleted}
                      onChange={() => handleToggle(habit.id)}
                      style={{
                        width: "1.25rem",
                        height: "1.25rem",
                        cursor: "pointer",
                      }}
                    />
                    <span
                      style={{
                        textDecoration: isCompleted ? "line-through" : "none",
                        opacity: isCompleted ? 0.6 : 1,
                      }}
                    >
                      {habit.name}
                    </span>
                  </label>
                );
              })}
            </div>
          </>
        )}
      </div>
    </article>
  );
}
