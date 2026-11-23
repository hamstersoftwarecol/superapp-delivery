import { SubmitButton } from "@/components/submit-button";
import { updateOrderStatus } from "../actions";

export const rejectionReasons = ["Sin ingredientes", "Estamos cerrando la cocina", "Demasiados pedidos", "Otro"];

export const cancellationReasons = ["Se agotó un ingrediente", "Problema en la cocina", "Demasiados pedidos", "Otro"];

/**
 * A button that opens a small form asking why. Rejecting or cancelling an
 * order affects the customer, so the API will not accept it without a reason.
 */
export function ReasonForm({
  orderId,
  status,
  label,
  reasons,
}: {
  orderId: number;
  status: "rejected" | "cancelled";
  label: string;
  reasons: string[];
}) {
  const id = `${status}-${orderId}`;

  return (
    <details className="w-full">
      <summary className="inline-flex min-h-10 cursor-pointer list-none items-center rounded-lg px-4 text-sm font-medium text-red-600 hover:bg-red-50 dark:hover:bg-red-950">
        {label}
      </summary>
      <form action={updateOrderStatus} className="mt-2 space-y-2 rounded-lg border border-zinc-200 p-3 dark:border-zinc-800">
        <input type="hidden" name="orderId" value={orderId} />
        <input type="hidden" name="status" value={status} />
        <label htmlFor={`${id}-reason`} className="text-xs font-medium text-zinc-600 dark:text-zinc-400">
          Motivo
        </label>
        <select
          id={`${id}-reason`}
          name="reason"
          required
          className="block min-h-10 w-full rounded-lg border border-zinc-300 bg-white px-2 text-sm dark:border-zinc-700 dark:bg-zinc-900"
        >
          {reasons.map((reason) => (
            <option key={reason}>{reason}</option>
          ))}
        </select>
        <label htmlFor={`${id}-detail`} className="sr-only">
          Detalle (obligatorio si eliges &quot;Otro&quot;)
        </label>
        <input
          id={`${id}-detail`}
          name="detail"
          maxLength={150}
          placeholder="Detalle (obligatorio si eliges “Otro”)"
          className="block min-h-10 w-full rounded-lg border border-zinc-300 bg-white px-3 text-sm dark:border-zinc-700 dark:bg-zinc-900"
        />
        <SubmitButton variant="danger">Confirmar</SubmitButton>
      </form>
    </details>
  );
}
