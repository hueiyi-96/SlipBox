export type ReceiptFile = {
  bytes: ArrayBuffer;
  contentType: string;
};

/** Fields the phone app is allowed to know about. Provider-specific names stay in the adapter. */
export type ExtractedReceipt = {
  merchant: string | null;
  purchasedOn: string | null;
  totalCents: number | null;
  taxCents: number | null;
  currency: string | null;
  receiptNumber: string | null;
};

export type ReceiptEntity = {
  type?: string;
  type_?: string;
  mentionText?: string;
  mention_text?: string;
  confidence?: number;
  normalizedValue?: { text?: string };
  normalized_value?: { text?: string };
};

/**
 * The only OCR contract in TracePay. `index.ts` chooses the class that
 * implements this. Replacing Google means replacing that class.
 */
export interface ReceiptExtractionService {
  extract(file: ReceiptFile): Promise<ExtractedReceipt>;
}

export function entitiesToReceipt(entities: ReceiptEntity[]): ExtractedReceipt {
  return {
    merchant: textOf(entities, "supplier_name"),
    purchasedOn: dateOf(entities, "receipt_date"),
    totalCents: moneyOf(entities, "total_amount"),
    taxCents: moneyOf(entities, "total_tax_amount"),
    currency: textOf(entities, "currency"),
    receiptNumber: null,
  };
}

function textOf(entities: ReceiptEntity[], type: string): string | null {
  const entity = best(entities, type);
  if (!entity) {
    return null;
  }
  const normalized = entity.normalizedValue?.text ?? entity.normalized_value?.text;
  const mentioned = entity.mentionText ?? entity.mention_text;
  const value = (normalized || mentioned || "").trim();
  return value.length > 0 ? value : null;
}

function dateOf(entities: ReceiptEntity[], type: string): string | null {
  const value = textOf(entities, type);
  if (value && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }
  return null;
}

function moneyOf(entities: ReceiptEntity[], type: string): number | null {
  return moneyToCents(textOf(entities, type) ?? undefined);
}

export function moneyToCents(raw: string | undefined): number | null {
  if (!raw) {
    return null;
  }
  const cleaned = raw.replace(/[^0-9.-]/g, "");
  const amount = Number(cleaned);
  if (!Number.isFinite(amount)) {
    return null;
  }
  const negative = cleaned.startsWith("-");
  const [whole, fraction = ""] = cleaned.replace("-", "").split(".");
  if (!/^\d+$/.test(whole)) {
    return null;
  }
  const cents =
    Number(whole) * 100 + Number((fraction + "00").slice(0, 2) || "0");
  return negative ? -cents : cents;
}

function best(entities: ReceiptEntity[], type: string): ReceiptEntity | null {
  let winner: ReceiptEntity | null = null;
  for (const entity of entities) {
    const name = entity.type ?? entity.type_;
    if (name !== type) {
      continue;
    }
    if (!winner || (entity.confidence ?? 0) >= (winner.confidence ?? 0)) {
      winner = entity;
    }
  }
  return winner;
}
