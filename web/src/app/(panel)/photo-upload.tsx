import { SubmitButton } from "@/components/submit-button";

const ACCEPT = "image/jpeg,image/png,image/webp";

/**
 * A file picker with its upload button, and a "remove" button when the item
 * already has a photo. The server actions are passed in so the same control
 * serves both the restaurant and its dishes.
 */
export function PhotoUpload({
  label,
  hiddenFields,
  hasPhoto,
  upload,
  remove,
}: {
  label: string;
  hiddenFields: Record<string, string | number>;
  hasPhoto: boolean;
  upload: (formData: FormData) => Promise<void>;
  remove: (formData: FormData) => Promise<void>;
}) {
  const fields = Object.entries(hiddenFields).map(([name, value]) => (
    <input key={name} type="hidden" name={name} value={value} />
  ));

  return (
    <div className="space-y-2">
      <form action={upload} className="flex flex-wrap items-end gap-2">
        {fields}
        <div>
          <label className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
            {label}
            <input
              type="file"
              name="image"
              accept={ACCEPT}
              required
              className="mt-1 block text-sm text-zinc-600 file:mr-3 file:rounded-lg file:border-0 file:bg-zinc-100 file:px-3 file:py-2 file:text-sm file:font-medium hover:file:bg-zinc-200 dark:text-zinc-400 dark:file:bg-zinc-800 dark:hover:file:bg-zinc-700"
            />
          </label>
        </div>
        <SubmitButton variant="secondary">{hasPhoto ? "Cambiar foto" : "Subir foto"}</SubmitButton>
      </form>
      <p className="text-xs text-zinc-500">JPG, PNG o WebP, hasta 5 MB y al menos 200 × 200 píxeles.</p>
      {hasPhoto && (
        <form action={remove}>
          {fields}
          <SubmitButton variant="danger">Quitar foto</SubmitButton>
        </form>
      )}
    </div>
  );
}
