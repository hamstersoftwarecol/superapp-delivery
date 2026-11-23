import { useId } from "react";

type FieldProps = {
  label: string;
  name: string;
  id?: string;
  type?: string;
  defaultValue?: string | number;
  placeholder?: string;
  required?: boolean;
  autoComplete?: string;
  step?: string;
  min?: string;
  errors?: string[];
  multiline?: boolean;
};

const inputClass =
  "mt-1 block w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-orange-600 focus:outline-none focus:ring-2 focus:ring-orange-600/30 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100";

export function Field({ label, name, id, errors, multiline, ...props }: FieldProps) {
  // Cache Components keeps previously visited routes mounted (hidden), so a
  // fixed id like "name" would be duplicated across pages and break labels.
  const generatedId = useId();
  const inputId = id ?? `${name}-${generatedId}`;
  const errorId = errors?.length ? `${inputId}-error` : undefined;

  return (
    <div>
      <label htmlFor={inputId} className="text-sm font-medium text-zinc-700 dark:text-zinc-300">
        {label}
      </label>
      {multiline ? (
        <textarea
          id={inputId}
          name={name}
          rows={3}
          defaultValue={props.defaultValue}
          placeholder={props.placeholder}
          aria-describedby={errorId}
          className={inputClass}
        />
      ) : (
        <input
          id={inputId}
          name={name}
          aria-invalid={errors?.length ? true : undefined}
          aria-describedby={errorId}
          className={inputClass}
          {...props}
        />
      )}
      {errors?.map((message) => (
        <p key={message} id={errorId} className="mt-1 text-sm text-red-600" role="alert">
          {message}
        </p>
      ))}
    </div>
  );
}
