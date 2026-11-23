import type { Metadata } from "next";
import { AutoRefresh } from "@/components/auto-refresh";
import { SubmitButton } from "@/components/submit-button";
import { apiFetch } from "@/lib/api";
import { getCurrentUser } from "@/lib/dal";
import { formatCents, formatTime } from "@/lib/format";
import type { Collection, Order, OrderStatus } from "@/lib/types";
import { updateOrderStatus } from "../actions";

export const metadata: Metadata = { title: "Pedidos" };

type Action = { to: OrderStatus; label: string; variant?: "primary" | "danger" };

const columns: { status: OrderStatus; title: string; actions: Action[] }[] = [
  {
    status: "pending",
    title: "Nuevos",
    actions: [
      { to: "accepted", label: "Aceptar" },
      { to: "rejected", label: "Rechazar", variant: "danger" },
    ],
  },
  { status: "accepted", title: "Aceptados", actions: [{ to: "preparing", label: "Empezar a preparar" }] },
  { status: "preparing", title: "En preparación", actions: [{ to: "ready", label: "Marcar listo" }] },
  { status: "ready", title: "Listos", actions: [] },
  { status: "picked_up", title: "En camino", actions: [] },
];

const historyLabels: Partial<Record<OrderStatus, string>> = {
  delivered: "Entregado",
  rejected: "Rechazado",
  cancelled: "Cancelado",
};

export default async function OrdersPage({ searchParams }: PageProps<"/orders">) {
  await getCurrentUser();
  const { error } = await searchParams;
  const { data: orders } = await apiFetch<Collection<Order>>("/orders");

  const history = orders.filter((order) => order.status in historyLabels);

  return (
    <div>
      <AutoRefresh seconds={10} />
      <h1 className="mb-4 text-2xl font-semibold tracking-tight">Pedidos</h1>

      {typeof error === "string" && (
        <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {error}
        </p>
      )}

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
        {columns.map((column) => {
          const columnOrders = orders.filter((order) => order.status === column.status);
          return (
            <section key={column.status} aria-labelledby={`col-${column.status}`}>
              <h2 id={`col-${column.status}`} className="mb-2 flex items-center justify-between text-sm font-semibold text-zinc-600 dark:text-zinc-400">
                {column.title}
                <span className="rounded-full bg-zinc-200 px-2 py-0.5 text-xs dark:bg-zinc-800">{columnOrders.length}</span>
              </h2>
              <div className="space-y-3">
                {columnOrders.length === 0 && (
                  <p className="rounded-xl border border-dashed border-zinc-300 p-4 text-center text-sm text-zinc-400 dark:border-zinc-800">
                    Sin pedidos
                  </p>
                )}
                {columnOrders.map((order) => (
                  <OrderCard key={order.id} order={order} actions={column.actions} />
                ))}
              </div>
            </section>
          );
        })}
      </div>

      {history.length > 0 && (
        <section className="mt-10" aria-labelledby="history">
          <h2 id="history" className="mb-2 text-sm font-semibold text-zinc-600 dark:text-zinc-400">
            Historial reciente
          </h2>
          <ul className="divide-y divide-zinc-200 rounded-xl border border-zinc-200 bg-white text-sm dark:divide-zinc-800 dark:border-zinc-800 dark:bg-zinc-950">
            {history.map((order) => (
              <li key={order.id} className="flex items-center justify-between px-4 py-3">
                <span>
                  #{order.id} · {order.customer?.name} · {formatTime(order.created_at)}
                </span>
                <span className="text-zinc-500">
                  {historyLabels[order.status]} · {formatCents(order.total_cents)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}

function OrderCard({ order, actions }: { order: Order; actions: Action[] }) {
  return (
    <article className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
      <header className="flex items-baseline justify-between">
        <h3 className="font-semibold">#{order.id}</h3>
        <time dateTime={order.created_at} className="text-xs text-zinc-500">
          {formatTime(order.created_at)}
        </time>
      </header>
      <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{order.customer?.name}</p>

      <ul className="mt-3 space-y-1 text-sm">
        {order.items?.map((item) => (
          <li key={item.id} className="flex justify-between gap-2">
            <span>
              {item.quantity} × {item.name}
            </span>
            <span className="tabular-nums text-zinc-500">{formatCents(item.unit_price_cents * item.quantity)}</span>
          </li>
        ))}
      </ul>

      <p className="mt-3 flex justify-between border-t border-zinc-100 pt-2 text-sm font-semibold dark:border-zinc-800">
        <span>Total</span>
        <span className="tabular-nums">{formatCents(order.total_cents)}</span>
      </p>
      <p className="mt-2 text-xs text-zinc-500">📍 {order.delivery_address}</p>
      {order.notes && <p className="mt-1 text-xs italic text-zinc-500">“{order.notes}”</p>}

      {order.status === "ready" && (
        <p className="mt-3 text-xs font-medium text-orange-700 dark:text-orange-400">
          {order.courier ? `Repartidor: ${order.courier.name}` : "Esperando repartidor…"}
        </p>
      )}
      {order.status === "picked_up" && order.courier && (
        <p className="mt-3 text-xs font-medium text-orange-700 dark:text-orange-400">Repartidor: {order.courier.name}</p>
      )}

      {actions.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2">
          {actions.map((action) => (
            <form key={action.to} action={updateOrderStatus}>
              <input type="hidden" name="orderId" value={order.id} />
              <input type="hidden" name="status" value={action.to} />
              <SubmitButton variant={action.variant ?? "primary"}>{action.label}</SubmitButton>
            </form>
          ))}
        </div>
      )}
    </article>
  );
}
