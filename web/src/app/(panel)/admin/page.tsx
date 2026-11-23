import type { Metadata } from "next";
import Link from "next/link";
import { SubmitButton } from "@/components/submit-button";
import { apiFetch } from "@/lib/api";
import { requireAdmin } from "@/lib/dal";
import { formatCents, formatDate } from "@/lib/format";
import type { AccountStatus, Collection, User, UserRole } from "@/lib/types";
import { setAccountStatus } from "./actions";

export const metadata: Metadata = { title: "Cuentas" };

const tabs: { key: string; label: string; status?: AccountStatus }[] = [
  { key: "pending", label: "Pendientes", status: "pending" },
  { key: "approved", label: "Aprobadas", status: "approved" },
  { key: "suspended", label: "Suspendidas", status: "suspended" },
  { key: "all", label: "Todas" },
];

const roleLabels: Record<UserRole, string> = {
  customer: "Cliente",
  restaurant: "Restaurante",
  courier: "Repartidor",
  admin: "Administrador",
};

const statusStyles: Record<AccountStatus, string> = {
  pending: "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300",
  approved: "bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300",
  suspended: "bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300",
};

const statusLabels: Record<AccountStatus, string> = {
  pending: "Pendiente",
  approved: "Aprobada",
  suspended: "Suspendida",
};

export default async function AdminAccountsPage({ searchParams }: PageProps<"/admin">) {
  await requireAdmin();

  const { tab: tabParam, error } = await searchParams;
  const tab = tabs.find((candidate) => candidate.key === tabParam) ?? tabs[0];
  const query = tab.status ? `?status=${tab.status}` : "";
  const { data: accounts } = await apiFetch<Collection<User>>(`/admin/accounts${query}`);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold tracking-tight">Cuentas</h1>

      <nav aria-label="Estado de las cuentas" className="flex flex-wrap gap-2">
        {tabs.map((candidate) => (
          <Link
            key={candidate.key}
            href={`/admin?tab=${candidate.key}`}
            aria-current={candidate.key === tab.key ? "page" : undefined}
            className={`rounded-lg px-3 py-1.5 text-sm ${
              candidate.key === tab.key
                ? "bg-orange-600 text-white"
                : "border border-zinc-300 hover:bg-zinc-100 dark:border-zinc-700 dark:hover:bg-zinc-900"
            }`}
          >
            {candidate.label}
          </Link>
        ))}
      </nav>

      {typeof error === "string" && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {error}
        </p>
      )}

      {accounts.length === 0 ? (
        <p className="rounded-xl border border-dashed border-zinc-300 p-10 text-center text-sm text-zinc-500 dark:border-zinc-800">
          {tab.status === "pending" ? "No hay cuentas esperando revisión." : "No hay cuentas en esta lista."}
        </p>
      ) : (
        <ul className="space-y-3">
          {accounts.map((account) => (
            <AccountCard key={account.id} account={account} back={`/admin?tab=${tab.key}`} />
          ))}
        </ul>
      )}
    </div>
  );
}

function AccountCard({ account, back }: { account: User; back: string }) {
  return (
    <li className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="flex flex-wrap items-center gap-2">
            <span className="font-semibold">{account.name}</span>
            <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-xs dark:bg-zinc-800">{roleLabels[account.role]}</span>
            <span className={`rounded-full px-2 py-0.5 text-xs ${statusStyles[account.status]}`}>{statusLabels[account.status]}</span>
          </p>
          <p className="mt-1 text-sm text-zinc-500">
            {account.email}
            {account.phone && ` · ${account.phone}`} · Registrada el {formatDate(account.created_at)}
          </p>
          {account.status === "suspended" && account.status_note && (
            <p className="mt-1 text-sm text-red-700 dark:text-red-300">Motivo: {account.status_note}</p>
          )}
        </div>

        <AccountActions account={account} back={back} />
      </div>

      {account.role === "restaurant" && (
        <div className="mt-3 border-t border-zinc-100 pt-3 text-sm dark:border-zinc-800">
          {account.restaurants && account.restaurants.length > 0 ? (
            <ul className="space-y-1">
              {account.restaurants.map((restaurant) => (
                <li key={restaurant.id}>
                  <span className="font-medium">{restaurant.name}</span>
                  <span className="text-zinc-500">
                    {" "}
                    · {restaurant.address} · Envío {formatCents(restaurant.delivery_fee_cents)}
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-zinc-500">Aún no ha creado su restaurante.</p>
          )}
        </div>
      )}
    </li>
  );
}

function AccountActions({ account, back }: { account: User; back: string }) {
  const hidden = (status: string) => (
    <>
      <input type="hidden" name="id" value={account.id} />
      <input type="hidden" name="status" value={status} />
      <input type="hidden" name="back" value={back} />
    </>
  );

  return (
    <div className="flex flex-wrap items-center gap-2">
      {account.status !== "approved" && (
        <form action={setAccountStatus}>
          {hidden("approved")}
          <SubmitButton>{account.status === "suspended" ? "Reactivar" : "Aprobar"}</SubmitButton>
        </form>
      )}
      {account.status !== "suspended" && (
        <form action={setAccountStatus} className="flex flex-wrap items-center gap-2">
          {hidden("suspended")}
          <label className="sr-only" htmlFor={`note-${account.id}`}>
            Motivo (opcional)
          </label>
          <input
            id={`note-${account.id}`}
            name="note"
            placeholder="Motivo (opcional)"
            maxLength={255}
            className="min-h-10 w-48 rounded-lg border border-zinc-300 bg-white px-3 text-sm dark:border-zinc-700 dark:bg-zinc-900"
          />
          <SubmitButton variant="danger">{account.status === "pending" ? "Rechazar" : "Suspender"}</SubmitButton>
        </form>
      )}
    </div>
  );
}
