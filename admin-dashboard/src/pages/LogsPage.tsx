import { useEffect, useState, useCallback } from "react";
import AdminLayout from "../components/AdminLayout";
import { fetchAdminLogs } from "../services/api";
import { formatDistanceToNow } from "date-fns";
import { fr } from "date-fns/locale";

interface LogEntry {
  id: string;
  adminUid: string;
  action: string;
  targetUid: string;
  timestamp?: { _seconds: number; _nanoseconds: number } | string;
}

export default function LogsPage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchAdminLogs(100);
      setLogs(data);
    } catch (err) {
      console.error("Failed to load logs", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const getActionDetails = (action: string) => {
    switch (action) {
      case "user_deleted":
        return { label: "Suppression de compte", className: "delete" };
      case "user_status_changed_to_banned":
        return { label: "Bannissement d'utilisateur", className: "ban" };
      case "user_status_changed_to_suspended":
        return { label: "Suspension d'utilisateur", className: "ban" };
      case "user_status_changed_to_active":
        return { label: "Réactivation d'utilisateur", className: "status" };
      default:
        return { label: action, className: "default" };
    }
  };

  const parseDate = (ts: any) => {
    if (!ts) return "Date inconnue";
    const date = ts._seconds ? new Date(ts._seconds * 1000) : new Date(ts);
    return formatDistanceToNow(date, { addSuffix: true, locale: fr });
  };

  return (
    <AdminLayout onRefresh={loadLogs}>
      <div className="page-header">
        <div>
          <h2>Journaux d'administration</h2>
          <p>Historique des actions critiques effectuées par les administrateurs</p>
        </div>
      </div>

      <div className="table-card">
        <div style={{ padding: "10px 24px" }}>
          {loading ? (
            <div className="loading-spinner">
              <div className="spinner" />
            </div>
          ) : logs.length === 0 ? (
            <div className="empty-state">Aucun journal trouvé.</div>
          ) : (
            logs.map((log) => {
              const details = getActionDetails(log.action);
              return (
                <div key={log.id} className="log-entry">
                  <div className={`log-dot ${details.className}`} />
                  <div>
                    <div className="log-action">{details.label}</div>
                    <div className="log-meta">
                      Cible: <code>{log.targetUid}</code> · Admin: <code>{log.adminUid}</code> · {parseDate(log.timestamp)}
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
