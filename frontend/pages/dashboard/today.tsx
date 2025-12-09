/**
 * LearnLynk Tech Test - Task 4: Today's Tasks Dashboard
 * Author: Vividh Laban
 * Description: Page displaying today's tasks with mark complete functionality
 */

import { useEffect, useState, useCallback } from "react";
import { supabase } from "../../lib/supabaseClient";

// Type definitions
type Task = {
  id: string;
  type: "call" | "email" | "review";
  status: string;
  application_id: string;
  due_at: string;
  title?: string;
  created_at: string;
};

// Task type icons/badges for visual distinction
const taskTypeConfig: Record<string, { emoji: string; color: string }> = {
  call: { emoji: "📞", color: "#10b981" },
  email: { emoji: "📧", color: "#3b82f6" },
  review: { emoji: "📋", color: "#8b5cf6" },
};

export default function TodayDashboard() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatingTaskId, setUpdatingTaskId] = useState<string | null>(null);

  /**
   * Get start and end of today in ISO format for filtering
   */
  const getTodayRange = () => {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    
    return {
      start: startOfDay.toISOString(),
      end: endOfDay.toISOString(),
    };
  };

  /**
   * Fetch tasks that are due today and not completed
   */
  const fetchTasks = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const { start, end } = getTodayRange();

      const { data, error: fetchError } = await supabase
        .from("tasks")
        .select("id, type, status, application_id, due_at, title, created_at")
        .gte("due_at", start)        // due_at >= start of today
        .lt("due_at", end)           // due_at < start of tomorrow
        .neq("status", "completed")  // status != completed
        .order("due_at", { ascending: true });

      if (fetchError) {
        throw fetchError;
      }

      setTasks(data || []);
    } catch (err: unknown) {
      console.error("Error fetching tasks:", err);
      const errorMessage = err instanceof Error ? err.message : "Failed to load tasks";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  /**
   * Mark a task as completed
   */
  const markComplete = async (taskId: string) => {
    setUpdatingTaskId(taskId);

    try {
      const { error: updateError } = await supabase
        .from("tasks")
        .update({ 
          status: "completed",
          updated_at: new Date().toISOString()
        })
        .eq("id", taskId);

      if (updateError) {
        throw updateError;
      }

      // Optimistically remove the task from the list
      setTasks((prevTasks) => prevTasks.filter((t) => t.id !== taskId));
    } catch (err: unknown) {
      console.error("Error marking task complete:", err);
      const errorMessage = err instanceof Error ? err.message : "Failed to update task";
      alert(errorMessage);
    } finally {
      setUpdatingTaskId(null);
    }
  };

  /**
   * Format due time for display
   */
  const formatDueTime = (dueAt: string) => {
    const date = new Date(dueAt);
    return date.toLocaleTimeString([], { 
      hour: "2-digit", 
      minute: "2-digit",
      hour12: true 
    });
  };

  /**
   * Check if task is overdue
   */
  const isOverdue = (dueAt: string) => {
    return new Date(dueAt) < new Date();
  };

  // Fetch tasks on component mount
  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  // Loading state
  if (loading) {
    return (
      <main style={styles.container}>
        <div style={styles.loadingContainer}>
          <div style={styles.spinner}></div>
          <p style={styles.loadingText}>Loading today&apos;s tasks...</p>
        </div>
      </main>
    );
  }

  // Error state
  if (error) {
    return (
      <main style={styles.container}>
        <div style={styles.errorContainer}>
          <p style={styles.errorText}>⚠️ {error}</p>
          <button onClick={fetchTasks} style={styles.retryButton}>
            Try Again
          </button>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>📅 Today&apos;s Tasks</h1>
        <p style={styles.subtitle}>
          {new Date().toLocaleDateString("en-US", {
            weekday: "long",
            year: "numeric",
            month: "long",
            day: "numeric",
          })}
        </p>
        <button onClick={fetchTasks} style={styles.refreshButton}>
          🔄 Refresh
        </button>
      </header>

      {tasks.length === 0 ? (
        <div style={styles.emptyState}>
          <p style={styles.emptyEmoji}>🎉</p>
          <p style={styles.emptyText}>No tasks due today!</p>
          <p style={styles.emptySubtext}>Enjoy your free time or plan ahead.</p>
        </div>
      ) : (
        <>
          <p style={styles.taskCount}>
            {tasks.length} task{tasks.length !== 1 ? "s" : ""} remaining
          </p>
          <div style={styles.tableContainer}>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Type</th>
                  <th style={styles.th}>Title</th>
                  <th style={styles.th}>Application ID</th>
                  <th style={styles.th}>Due At</th>
                  <th style={styles.th}>Status</th>
                  <th style={styles.th}>Action</th>
                </tr>
              </thead>
              <tbody>
                {tasks.map((task) => {
                  const config = taskTypeConfig[task.type] || { emoji: "📌", color: "#6b7280" };
                  const overdue = isOverdue(task.due_at);

                  return (
                    <tr key={task.id} style={overdue ? styles.overdueRow : styles.tr}>
                      <td style={styles.td}>
                        <span
                          style={{
                            ...styles.typeBadge,
                            backgroundColor: `${config.color}20`,
                            color: config.color,
                          }}
                        >
                          {config.emoji} {task.type}
                        </span>
                      </td>
                      <td style={styles.td}>{task.title || "-"}</td>
                      <td style={styles.td}>
                        <code style={styles.code}>
                          {task.application_id.slice(0, 8)}...
                        </code>
                      </td>
                      <td style={styles.td}>
                        <span style={overdue ? styles.overdueTime : {}}>
                          {formatDueTime(task.due_at)}
                          {overdue && " (overdue)"}
                        </span>
                      </td>
                      <td style={styles.td}>
                        <span style={styles.statusBadge}>{task.status}</span>
                      </td>
                      <td style={styles.td}>
                        <button
                          onClick={() => markComplete(task.id)}
                          disabled={updatingTaskId === task.id}
                          style={{
                            ...styles.completeButton,
                            opacity: updatingTaskId === task.id ? 0.6 : 1,
                          }}
                        >
                          {updatingTaskId === task.id ? "Updating..." : "Mark Complete"}
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </>
      )}
    </main>
  );
}

// Inline styles for simplicity (no external CSS dependencies)
const styles: Record<string, React.CSSProperties> = {
  container: {
    maxWidth: "1200px",
    margin: "0 auto",
    padding: "2rem",
    fontFamily: "'Segoe UI', system-ui, -apple-system, sans-serif",
    minHeight: "100vh",
    backgroundColor: "#f8fafc",
  },
  header: {
    marginBottom: "2rem",
    display: "flex",
    flexDirection: "column",
    gap: "0.5rem",
  },
  title: {
    fontSize: "2rem",
    fontWeight: "700",
    color: "#1e293b",
    margin: 0,
  },
  subtitle: {
    fontSize: "1rem",
    color: "#64748b",
    margin: 0,
  },
  refreshButton: {
    alignSelf: "flex-start",
    marginTop: "0.5rem",
    padding: "0.5rem 1rem",
    fontSize: "0.875rem",
    backgroundColor: "#e2e8f0",
    color: "#475569",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
  },
  taskCount: {
    color: "#64748b",
    marginBottom: "1rem",
  },
  loadingContainer: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    minHeight: "50vh",
  },
  spinner: {
    width: "40px",
    height: "40px",
    border: "4px solid #e2e8f0",
    borderTopColor: "#3b82f6",
    borderRadius: "50%",
    animation: "spin 1s linear infinite",
  },
  loadingText: {
    marginTop: "1rem",
    color: "#64748b",
  },
  errorContainer: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    minHeight: "50vh",
    gap: "1rem",
  },
  errorText: {
    color: "#dc2626",
    fontSize: "1.125rem",
  },
  retryButton: {
    padding: "0.75rem 1.5rem",
    backgroundColor: "#3b82f6",
    color: "white",
    border: "none",
    borderRadius: "8px",
    cursor: "pointer",
    fontSize: "1rem",
  },
  emptyState: {
    textAlign: "center",
    padding: "4rem 2rem",
    backgroundColor: "white",
    borderRadius: "12px",
    boxShadow: "0 1px 3px rgba(0,0,0,0.1)",
  },
  emptyEmoji: {
    fontSize: "4rem",
    margin: 0,
  },
  emptyText: {
    fontSize: "1.5rem",
    fontWeight: "600",
    color: "#1e293b",
    margin: "1rem 0 0.5rem",
  },
  emptySubtext: {
    color: "#64748b",
    margin: 0,
  },
  tableContainer: {
    backgroundColor: "white",
    borderRadius: "12px",
    boxShadow: "0 1px 3px rgba(0,0,0,0.1)",
    overflow: "hidden",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
  },
  th: {
    textAlign: "left",
    padding: "1rem",
    backgroundColor: "#f1f5f9",
    fontWeight: "600",
    color: "#475569",
    fontSize: "0.875rem",
    textTransform: "uppercase",
    letterSpacing: "0.05em",
  },
  tr: {
    borderBottom: "1px solid #e2e8f0",
  },
  overdueRow: {
    borderBottom: "1px solid #e2e8f0",
    backgroundColor: "#fef2f2",
  },
  td: {
    padding: "1rem",
    color: "#334155",
  },
  typeBadge: {
    display: "inline-flex",
    alignItems: "center",
    gap: "0.25rem",
    padding: "0.25rem 0.75rem",
    borderRadius: "9999px",
    fontSize: "0.875rem",
    fontWeight: "500",
    textTransform: "capitalize",
  },
  statusBadge: {
    display: "inline-block",
    padding: "0.25rem 0.75rem",
    backgroundColor: "#dbeafe",
    color: "#1d4ed8",
    borderRadius: "9999px",
    fontSize: "0.75rem",
    fontWeight: "500",
    textTransform: "capitalize",
  },
  code: {
    fontFamily: "'Fira Code', monospace",
    backgroundColor: "#f1f5f9",
    padding: "0.25rem 0.5rem",
    borderRadius: "4px",
    fontSize: "0.75rem",
  },
  overdueTime: {
    color: "#dc2626",
    fontWeight: "500",
  },
  completeButton: {
    padding: "0.5rem 1rem",
    backgroundColor: "#10b981",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontSize: "0.875rem",
    fontWeight: "500",
    transition: "opacity 0.2s",
  },
};
