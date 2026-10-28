import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NOVA DIGITEX | Ventas e inventario",
  description: "Plataforma web multiempresa para ventas, inventario y tiendas online.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
