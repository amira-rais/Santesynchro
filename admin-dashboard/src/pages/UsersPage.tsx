import { useEffect, useState, useCallback } from "react";
import { Search, Trash2, CheckCircle, ShieldAlert, Shield } from "lucide-react";
import AdminLayout from "../components/AdminLayout";
import { fetchUsers, updateUserStatus, deleteUser } from "../services/api";

interface User {
  uid: string;
  email: string;
  name: string;
  createdAt: string;
  status?: "active" | "banned" | "suspended";
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [nextPageToken, setNextPageToken] = useState<string | null>(null);

  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [modalAction, setModalAction] = useState<"ban" | "suspend" | "activate" | "delete" | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const loadUsers = useCallback(async (token?: string, refresh = false) => {
    if (refresh) setLoading(true);
    try {
      const data = await fetchUsers({ limit: 15, search, status: statusFilter, pageToken: token });
      setUsers(prev => (token && !refresh ? [...prev, ...data.users] : data.users));
      setNextPageToken(data.nextPageToken);
    } catch (err) {
      console.error("Failed to load users", err);
    } finally {
      setLoading(false);
    }
  }, [search, statusFilter]);

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => loadUsers(undefined, true), 300);
    return () => clearTimeout(timer);
  }, [search, statusFilter, loadUsers]);

  const handleAction = async () => {
    if (!selectedUser || !modalAction) return;
    setActionLoading(true);
    try {
      if (modalAction === "delete") {
        await deleteUser(selectedUser.uid);
      } else {
        const newStatus = modalAction === "activate" ? "active" : modalAction === "ban" ? "banned" : "suspended";
        await updateUserStatus(selectedUser.uid, newStatus);
      }
      setModalAction(null);
      setSelectedUser(null);
      loadUsers(undefined, true);
    } catch (err) {
      console.error(`Failed to ${modalAction} user`, err);
      alert(`Erreur lors de l'action ${modalAction}`);
    } finally {
      setActionLoading(false);
    }
  };

  const getStatusBadge = (status?: string) => {
    if (status === "banned") return <span className="badge banned">Banni</span>;
    if (status === "suspended") return <span className="badge suspended">Suspendu</span>;
    return <span className="badge active">Actif</span>;
  };

  return (
    <AdminLayout onRefresh={() => loadUsers(undefined, true)}>
      <div className="page-header">
        <div>
          <h2>Utilisateurs</h2>
          <p>Gérez les comptes, les accès et les sanctions</p>
        </div>
      </div>

      <div className="table-card">
        <div className="table-header">
          <h2>Liste des inscrits</h2>
          <div style={{ display: "flex", gap: 12, flexWrap: "wrap", flex: 1, justifyContent: "flex-end" }}>
            <div className="search-bar">
              <Search size={16} color="var(--text-dim)" />
              <input
                type="text"
                placeholder="Rechercher par nom ou email..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <select
              className="filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="">Tous les statuts</option>
              <option value="active">Actifs</option>
              <option value="suspended">Suspendus</option>
              <option value="banned">Bannis</option>
            </select>
          </div>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Utilisateur</th>
                <th>Inscription</th>
                <th>Statut</th>
                <th style={{ textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ textAlign: "center", padding: 40, color: "var(--text-dim)" }}>
                    Chargement...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ textAlign: "center", padding: 40, color: "var(--text-dim)" }}>
                    Aucun utilisateur trouvé.
                  </td>
                </tr>
              ) : (
                users.map((u) => (
                  <tr key={u.uid}>
                    <td>
                      <div className="user-cell">
                        <div className="user-avatar">{u.email?.charAt(0).toUpperCase() ?? "U"}</div>
                        <div>
                          <div className="user-name">{u.name || "Utilisateur sans nom"}</div>
                          <div className="user-email">{u.email}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ color: "var(--text-dim)" }}>
                      {u.createdAt ? new Date(u.createdAt).toLocaleDateString("fr-FR") : "N/A"}
                    </td>
                    <td>{getStatusBadge(u.status)}</td>
                    <td style={{ textAlign: "right" }}>
                      <div style={{ display: "inline-flex", gap: 6 }}>
                        {u.status === "banned" || u.status === "suspended" ? (
                          <button
                            className="btn-icon"
                            title="Réactiver"
                            onClick={() => { setSelectedUser(u); setModalAction("activate"); }}
                          >
                            <CheckCircle size={16} color="var(--accent-500)" />
                          </button>
                        ) : (
                          <>
                            <button
                              className="btn-icon"
                              title="Suspendre"
                              onClick={() => { setSelectedUser(u); setModalAction("suspend"); }}
                            >
                              <ShieldAlert size={16} color="#fbbf24" />
                            </button>
                            <button
                              className="btn-icon"
                              title="Bannir"
                              onClick={() => { setSelectedUser(u); setModalAction("ban"); }}
                            >
                              <Shield size={16} color="#f87171" />
                            </button>
                          </>
                        )}
                        <button
                          className="btn-icon"
                          title="Supprimer"
                          onClick={() => { setSelectedUser(u); setModalAction("delete"); }}
                        >
                          <Trash2 size={16} color="#ef4444" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {nextPageToken && (
          <div className="pagination">
            <span className="pagination-info">Plus de résultats disponibles</span>
            <button className="btn btn-ghost btn-sm" onClick={() => loadUsers(nextPageToken)} disabled={loading}>
              Charger la suite
            </button>
          </div>
        )}
      </div>

      {/* ── Modal de confirmation ── */}
      {modalAction && selectedUser && (
        <div className="modal-overlay" onClick={() => setModalAction(null)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h2>Confirmation d'action</h2>
            <p>
              Êtes-vous sûr de vouloir <strong>
                {modalAction === "ban" ? "bannir" :
                 modalAction === "suspend" ? "suspendre" :
                 modalAction === "activate" ? "réactiver" : "supprimer"}
              </strong> l'utilisateur <span style={{ color: "var(--text-primary)" }}>{selectedUser.email}</span> ?
              {modalAction === "delete" && " Cette action est irréversible et supprimera toutes ses données."}
              {modalAction === "ban" && " L'utilisateur ne pourra plus se connecter du tout."}
            </p>
            <div className="modal-actions">
              <button className="btn btn-ghost" onClick={() => setModalAction(null)} disabled={actionLoading}>
                Annuler
              </button>
              <button
                className={`btn ${modalAction === "delete" ? "btn-danger" : modalAction === "activate" ? "btn-primary" : "btn-warn"}`}
                onClick={handleAction}
                disabled={actionLoading}
              >
                {actionLoading ? "En cours..." : "Confirmer"}
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}
