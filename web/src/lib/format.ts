const currency = process.env.CURRENCY ?? "COP";

const money = new Intl.NumberFormat("es-CO", {
  style: "currency",
  currency,
  maximumFractionDigits: 0,
});

export function formatCents(cents: number): string {
  return money.format(cents / 100);
}

export function centsFromInput(value: FormDataEntryValue | null): number {
  const parsed = Number.parseFloat(String(value ?? "").replace(",", "."));
  return Number.isFinite(parsed) ? Math.round(parsed * 100) : 0;
}

export function inputFromCents(cents: number): string {
  return String(cents / 100);
}

const time = new Intl.DateTimeFormat("es-CO", { hour: "2-digit", minute: "2-digit" });

export function formatTime(iso: string): string {
  return time.format(new Date(iso));
}
