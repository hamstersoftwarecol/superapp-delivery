export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="text-3xl font-semibold tracking-tight text-orange-600">SuperApp Delivery</p>
          <p className="mt-1 text-sm text-zinc-500">Restaurantes y administración</p>
        </div>
        <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
          {children}
        </div>
      </div>
    </main>
  );
}
