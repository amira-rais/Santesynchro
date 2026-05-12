import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(email, password);
      navigate("/");
    } catch (err: any) {
      if (err?.code === "auth/invalid-credential" || err?.code === "auth/wrong-password") {
        setError("Email ou mot de passe incorrect.");
      } else if (err?.message?.includes("403") || err?.message?.includes("Forbidden")) {
        setError("Accès refusé : votre compte n'a pas les droits administrateur.");
      } else {
        setError("Une erreur s'est produite. Vérifiez vos identifiants.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <h1>🌿 SantéSynchro</h1>
          <p>Portail administrateur</p>
        </div>

        <form onSubmit={handleSubmit}>
          {error && <div className="error-msg">{error}</div>}

          <div className="form-group">
            <label htmlFor="email">Adresse e-mail</label>
            <input
              id="email"
              type="email"
              className="form-input"
              placeholder="admin@santesynchro.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoFocus
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Mot de passe</label>
            <input
              id="password"
              type="password"
              className="form-input"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            style={{ width: "100%", justifyContent: "center", padding: "13px" }}
            disabled={loading}
          >
            {loading ? "Connexion en cours…" : "Se connecter"}
          </button>
        </form>

        <p style={{ textAlign: "center", marginTop: 20, fontSize: ".75rem", color: "var(--text-dim)" }}>
          Accès réservé aux administrateurs SantéSynchro
        </p>
      </div>
    </div>
  );
}
