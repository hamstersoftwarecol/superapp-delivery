type PhotoProps = {
  src: string | null;
  alt: string;
  className?: string;
};

/**
 * A photo from the API, or a neutral placeholder when there is none.
 *
 * Plain <img> on purpose: the pictures are already resized and compressed by
 * the API, and next/image would block the API's local development address.
 */
export function Photo({ src, alt, className = "" }: PhotoProps) {
  if (!src) {
    return (
      <div
        role="img"
        aria-label={`${alt}: sin foto`}
        className={`flex items-center justify-center bg-zinc-100 text-zinc-400 dark:bg-zinc-900 ${className}`}
      >
        <svg viewBox="0 0 24 24" className="size-1/3" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <circle cx="9" cy="10" r="1.5" />
          <path d="m21 16-5-5-8 8" />
        </svg>
      </div>
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt={alt} loading="lazy" decoding="async" className={`object-cover ${className}`} />
  );
}
