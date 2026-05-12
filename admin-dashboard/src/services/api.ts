import axios from "axios";
import { auth } from "../firebase";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? "http://localhost:4000",
});

// Intercepteur : ajoute le token Firebase à chaque requête
api.interceptors.request.use(async (config) => {
  const user = auth.currentUser;
  if (user) {
    const token = await user.getIdToken();
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ─── KPIs ────────────────────────────────────────────────────────────────────
export const fetchStats = () => api.get("/api/admin/stats").then((r) => r.data);

// ─── Users ───────────────────────────────────────────────────────────────────
export const fetchUsers = (params: {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
  pageToken?: string;
}) => api.get("/api/admin/users", { params }).then((r) => r.data);

export const fetchUserDetail = (uid: string) =>
  api.get(`/api/admin/users/${uid}`).then((r) => r.data);

export const updateUserStatus = (
  uid: string,
  status: "active" | "banned" | "suspended"
) => api.patch(`/api/admin/users/${uid}/status`, { status }).then((r) => r.data);

export const deleteUser = (uid: string) =>
  api.delete(`/api/admin/users/${uid}`).then((r) => r.data);

// ─── Logs ─────────────────────────────────────────────────────────────────────
export const fetchAdminLogs = (limit = 50) =>
  api.get("/api/admin/logs", { params: { limit } }).then((r) => r.data);

export default api;
