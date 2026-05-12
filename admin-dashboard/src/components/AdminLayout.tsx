import type { ReactNode } from "react";
import Sidebar from "./Sidebar";
import Topbar from "./Topbar";

interface AdminLayoutProps {
  children: ReactNode;
  onRefresh?: () => void;
}

export default function AdminLayout({ children, onRefresh }: AdminLayoutProps) {
  return (
    <div className="app-layout">
      <Sidebar />
      <div className="main-content">
        <Topbar onRefresh={onRefresh} />
        <main className="page-content">{children}</main>
      </div>
    </div>
  );
}
