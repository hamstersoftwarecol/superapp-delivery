import type { Metadata } from "next";
import { AutoRefresh } from "@/components/auto-refresh";
import { SubmitButton } from "@/components/submit-button";
import { apiFetch } from "@/lib/api";
import { requireRestaurantOwner } from "@/lib/dal";
import { formatCents, formatTime } from "@/lib/format";
import type { Collection, CursorPage, Order, OrderActor, OrderStatus } from "@/lib/types";
import Link from "next/link";
import { updateOrderStatus } from "../actions";
import { cancellationReasons, ReasonForm, rejectionReasons } from "./reason-form";

export const metadata: Metadata = { title: "Pedidos" };

type Action = { to: OrderStatus; label: string };

/** What the restaurant can still do while an order is on its side of the process. */
type Column = { status: OrderStatus; title: string; actions: Action[]; hint?: string; canCancel?: boolean; canReject?: boolean };

const columns: Column[] = [
  {
    status: "pending",
    title: "Nuevos",
    actions: [{ to: "accepted", label: "Aceptar" }],
    canReject: true,
    hint: "Si no respondes a tiempo, el pedido se cancela solo.",
  },
  { status: "accepted", title: "Aceptados", actions: [{ to: "preparing", label: "Empezar a preparar" }], canCancel: true },
  { status: "preparing", title: "En preparación", actions: [{ to: "ready", label: "Marcar listo" }], canCancel: true },
  { status: "ready", title: "Listos", actions: [], canCancel: true },
  { status: "picked_up", title: "En camino", actions: [] },
];

const historyLabels: Partial<Record<OrderStatus, string>> = {
  delivered: "Entregado",
  rejected: "Rechazado",
  cancelled: "Cancelado",
  failed: "No se pudo entregar",
};

const actorLabels: Record<OrderActor, string> = {
  customer: "por el cliente",
  restaurant: "por ti",
  courier: "por el repartidor",
  system: "automáticamente",
};

export default async function OrdersPage({ searchParams }: PageProps<"/orders">) {
  await requireRestaurantOwner();
  const { error, history: historyCursor } = await searchParams;

  // Orders in progress always come whole, so none can hide on a later page.
  // The history is paged: its cursor travels in the address (?history=...).
  const historyQuery = typeof historyCursor === "string" ? `&cursor=${encodeURIComponent(historyCursor)}` : "";
  const [{ data: orders }, historyPage] = await Promise.all([
    apiFetch<Collection<Order>>("/orders?scope=active"),
    apiFetch<CursorPage<Order>>(`/orders?scope=history${historyQuery}`),
  ]);
  const history = historyPage.data;
  const { prev_cursor: newer, next_cursor: older } = historyPage.meta;

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
              {column.hint && <p className="mb-2 text-xs text-zinc-500">{column.hint}</p>}
              <div className="space-y-3">
                {columnOrders.length === 0 && (
                  <p className="rounded-xl border border-dashed border-zinc-300 p-4 text-center text-sm text-zinc-400 dark:border-zinc-800">
                    Sin pedidos
                  </p>
                )}
                {columnOrders.map((order) => (
                  <OrderCard key={order.id} order={order} column={column} />
                ))}
              </div>
            </section>
          );
        })}
      </div>

      {(history.length > 0 || newer) && (
        <section className="mt-10" aria-labelledby="history">
          <h2 id="history" className="mb-2 text-sm font-semibold text-zinc-600 dark:text-zinc-400">
            Historial reciente
          </h2>
          <ul className="divide-y divide-zinc-200 rounded-xl border border-zinc-200 bg-white text-sm dark:divide-zinc-800 dark:border-zinc-800 dark:bg-zinc-950">
            {history.map((order) => (
              <li key={order.id} className="px-4 py-3">
                <div className="flex items-center justify-between gap-3">
                  <span>
                    #{order.id} · {order.customer?.name} · {formatTime(order.created_at)}
                  </span>
                  <span className="text-zinc-500">
                    {historyLabels[order.status]}
                    {order.status_actor && order.status !== "delivered" && ` ${actorLabels[order.status_actor]}`} ·{" "}
                    {formatCents(order.total_cents)}
                  </span>
                </div>
                {order.status_reason && (
                  <p className="mt-1 text-xs text-zinc-500">Motivo: {order.status_reason}</p>
                )}
              </li>
            ))}
          </ul>
          {(newer || older) && (
            <nav aria-label="Páginas del historial" className="mt-3 flex items-center justify-between text-sm">
              {newer ? (
                <Link href={`/orders?history=${encodeURIComponent(newer)}`} className="font-medium text-orange-700 hover:underline dark:text-orange-400">
                  ← Más recientes
                </Link>
              ) : (
                <span />
              )}
              {older ? (
                <Link href={`/orders?history=${encodeURIComponent(older)}`} className="font-medium text-orange-700 hover:underline dark:text-orange-400">
                  Más antiguos →
                </Link>
              ) : (
                <span />
              )}
            </nav>
          )}
        </section>
      )}
    </div>
  );
}

function OrderCard({ order, column }: { order: Order; column: Column }) {
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

      {(column.actions.length > 0 || column.canReject || column.canCancel) && (
        <div className="mt-3 flex flex-wrap gap-2">
          {column.actions.map((action) => (
            <form key={action.to} action={updateOrderStatus}>
              <input type="hidden" name="orderId" value={order.id} />
              <input type="hidden" name="status" value={action.to} />
              <SubmitButton>{action.label}</SubmitButton>
            </form>
          ))}
          {column.canReject && <ReasonForm orderId={order.id} status="rejected" label="Rechazar" reasons={rejectionReasons} />}
          {column.canCancel && (
            <ReasonForm orderId={order.id} status="cancelled" label="Cancelar pedido" reasons={cancellationReasons} />
          )}
        </div>
      )}
    </article>
  );
}
