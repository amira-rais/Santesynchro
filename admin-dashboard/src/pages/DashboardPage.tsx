import { useEffect, useState, useCallback } from "react";
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, BarChart, Bar,
} from "recharts";
import {
  Users, Activity, Clock, TrendingUp,
} from "lucide-react";
import AdminLayout from "../components/AdminLayout";
import { fetchStats } from "../services/api";

interface Stats {
  totalUsers: number;
  activeUsersMonthly: number;
  activeUsersDaily: number;
  totalSessions: number;
  avgSessionMinutes: number;
  userStatusDistribution: { active: number; banned: number; suspended: number };
  dailyUserGrowth: Record<string, number>;
  dailySessions: Record<string, number>;
}

const STATUS_COLORS = ["#10b981", "#ef4444", "#f59e0b"];

const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload?.length) {
    return (
      <div style={{
        background: "var(--surface-2)", border: "1px solid var(--border)",
        borderRadius: 8, padding: "10px 14px", fontSize: ".8rem",
      }}>
        <p style={{ color: "var(--text-dim)", marginBottom: 4 }}>{label}</p>
        {payload.map((p: any) => (
          <p key={p.name} style={{ color: p.color, fontWeight: 600 }}>
            {p.name}: {p.value}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await fetchStats();
      setStats(data);
    } catch {
      setError("Impossible de charger les statistiques.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Prépare les séries de données pour les graphiques
  const growthData = stats
    ? Object.entries(stats.dailyUserGrowth)
        .sort(([a], [b]) => a.localeCompare(b))
        .slice(-14)
        .map(([date, count]) => ({ date: date.slice(5), "Nouveaux utilisateurs": count }))
    : [];

  const sessionData = stats
    ? Object.entries(stats.dailySessions)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, count]) => ({ date: date.slice(5), Sessions: count }))
    : [];

  const pieData = stats
    ? [
        { name: "Actifs", value: stats.userStatusDistribution.active },
        { name: "Bannis", value: stats.userStatusDistribution.banned },
        { name: "Suspendus", value: stats.userStatusDistribution.suspended },
      ]
    : [];

  const kpis = stats
    ? [
        {
          icon: Users, colorClass: "emerald",
          value: stats.totalUsers,
          label: "Utilisateurs total",
          change: "+12%",
          up: true,
        },
        {
          icon: Activity, colorClass: "blue",
          value: stats.activeUsersMonthly,
          label: "Actifs ce mois",
          change: `${stats.activeUsersDaily} aujourd'hui`,
          up: true,
        },
        {
          icon: TrendingUp, colorClass: "yellow",
          value: stats.totalSessions,
          label: "Sessions totales",
          change: `${Object.values(stats.dailySessions).slice(-1)[0] ?? 0} aujourd'hui`,
          up: true,
        },
        {
          icon: Clock, colorClass: "purple",
          value: `${stats.avgSessionMinutes} min`,
          label: "Durée moy. session",
          change: "Temps moyen",
          up: stats.avgSessionMinutes > 0,
        },
      ]
    : [];

  return (
    <AdminLayout onRefresh={load}>
      <div className="page-header">
        <div>
          <h2>Vue d'ensemble</h2>
          <p>Indicateurs clés de performance en temps réel</p>
        </div>
      </div>

      {loading && (
        <div className="loading-spinner">
          <div className="spinner" />
          <span>Chargement des statistiques…</span>
        </div>
      )}

      {error && (
        <div className="error-msg" style={{ marginBottom: 24 }}>{error}</div>
      )}

      {!loading && stats && (
        <>
          {/* ── KPI Cards ── */}
          <div className="kpi-grid">
            {kpis.map(({ icon: Icon, colorClass, value, label, change, up }) => (
              <div className="kpi-card" key={label}>
                <div className={`kpi-icon ${colorClass}`}>
                  <Icon size={20} />
                </div>
                <div className="kpi-value">{value}</div>
                <div className="kpi-label">{label}</div>
                <div className={`kpi-change ${up ? "up" : "down"}`}>
                  {change}
                </div>
              </div>
            ))}
          </div>

          {/* ── Charts ── */}
          <div className="charts-grid">
            {/* Croissance utilisateurs */}
            <div className="chart-card">
              <h3><TrendingUp size={16} /> Croissance des utilisateurs (14 jours)</h3>
              {growthData.length > 0 ? (
                <ResponsiveContainer width="100%" height={220}>
                  <LineChart data={growthData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(52,211,153,.08)" />
                    <XAxis dataKey="date" tick={{ fill: "#6b7280", fontSize: 11 }} />
                    <YAxis tick={{ fill: "#6b7280", fontSize: 11 }} />
                    <Tooltip content={<CustomTooltip />} />
                    <Line
                      type="monotone"
                      dataKey="Nouveaux utilisateurs"
                      stroke="#10b981"
                      strokeWidth={2.5}
                      dot={{ fill: "#10b981", r: 3 }}
                      activeDot={{ r: 5 }}
                    />
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <div className="empty-state">Pas encore de données d'inscription</div>
              )}
            </div>

            {/* Répartition statuts */}
            <div className="chart-card">
              <h3><Users size={16} /> Répartition des statuts</h3>
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%" cy="50%"
                    innerRadius={55} outerRadius={85}
                    paddingAngle={4}
                    dataKey="value"
                    label={({ name, percent }) => `${name} ${((percent || 0) * 100).toFixed(0)}%`}
                    labelLine={false}
                  >
                    {pieData.map((_, i) => (
                      <Cell key={i} fill={STATUS_COLORS[i]} />
                    ))}
                  </Pie>
                  <Tooltip content={<CustomTooltip />} />
                </PieChart>
              </ResponsiveContainer>
            </div>

            {/* Sessions par jour */}
            <div className="chart-card" style={{ gridColumn: "1 / -1" }}>
              <h3><Activity size={16} /> Sessions par jour (7 jours)</h3>
              {sessionData.length > 0 ? (
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={sessionData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(52,211,153,.08)" />
                    <XAxis dataKey="date" tick={{ fill: "#6b7280", fontSize: 11 }} />
                    <YAxis tick={{ fill: "#6b7280", fontSize: 11 }} />
                    <Tooltip content={<CustomTooltip />} />
                    <Bar dataKey="Sessions" fill="#10b981" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="empty-state">Aucune session enregistrée</div>
              )}
            </div>
          </div>
        </>
      )}
    </AdminLayout>
  );
}
