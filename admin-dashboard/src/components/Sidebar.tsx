import { NavLink, useNavigate } from "react-router-dom";
import {
  LayoutDashboard, Users, ScrollText, LogOut,
  Activity, HeartPulse,
} from "lucide-react";
import { useAuth } from "../contexts/AuthContext";

const navItems = [
  { to: "/", icon: LayoutDashboard, label: "Tableau de bord" },
  { to: "/users", icon: Users, label: "Utilisateurs" },
  { to: "/logs", icon: ScrollText, label: "Journaux" },
];

export default function Sidebar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate("/login");
  };

  const initials = user?.email?.charAt(0).toUpperCase() ?? "A";

  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <div className="logo-text">🌿 SantéSynchro</div>
        <div className="logo-sub">Administration</div>
      </div>

      <nav className="sidebar-nav">
        <div className="nav-section-title">Navigation</div>
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            className={({ isActive }) => `nav-item${isActive ? " active" : ""}`}
          >
            <Icon className="nav-icon" size={18} />
            {label}
          </NavLink>
        ))}

        <div className="nav-section-title" style={{ marginTop: 12 }}>Système</div>
        <div className="nav-item" style={{ cursor: "default", opacity: .6 }}>
          <Activity className="nav-icon" size={18} />
          Santé des services
        </div>
        <div className="nav-item" style={{ cursor: "default", opacity: .6 }}>
          <HeartPulse className="nav-icon" size={18} />
          API backend : actif
        </div>
      </nav>

      <div className="sidebar-footer">
        <div className="sidebar-user">
          <div className="avatar">{initials}</div>
          <div className="user-info">
            <div className="user-email">{user?.email}</div>
            <div className="user-role">Admin</div>
          </div>
          <button
            className="btn-icon"
            onClick={handleLogout}
            title="Se déconnecter"
          >
            <LogOut size={15} />
          </button>
        </div>
      </div>
    </aside>
  );
}
