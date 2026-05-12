import { useLocation } from "react-router-dom";
import { RefreshCw } from "lucide-react";

const pageMeta: Record<string, { title: string; subtitle: string }> = {
  "/":      { title: "Tableau de bord", subtitle: "Vue d'ensemble des KPIs" },
  "/users": { title: "Utilisateurs",    subtitle: "Gérer les comptes utilisateurs" },
  "/logs":  { title: "Journaux",         subtitle: "Historique des actions administrateur" },
};

interface TopbarProps {
  onRefresh?: () => void;
}

export default function Topbar({ onRefresh }: TopbarProps) {
  const { pathname } = useLocation();
  const meta = pageMeta[pathname] ?? { title: "Admin", subtitle: "" };
  const now = new Date().toLocaleDateString("fr-FR", {
    weekday: "long", day: "numeric", month: "long", year: "numeric",
  });

  return (
    <header className="topbar">
      <div className="topbar-title">
        <h1>{meta.title}</h1>
        <div className="subtitle">{now} · {meta.subtitle}</div>
      </div>
      <div className="topbar-actions">
        <div className="topbar-badge">
          <span className="dot" />
          API en ligne
        </div>
        {onRefresh && (
          <button className="btn-icon" onClick={onRefresh} title="Rafraîchir">
            <RefreshCw size={15} />
          </button>
        )}
      </div>
    </header>
  );
}
