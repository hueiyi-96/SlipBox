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
    currency: normalizeCurrency(textOf(entities, "currency")),
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
  const trimmed = raw.trim();
  const negative = trimmed.startsWith("-");
  const unsigned = negative ? trimmed.slice(1).trim() : trimmed;
  const stripped = unsigned
    .replace(/^(?:[A-Za-z]{1,3}\$?|[$€£¥])\s*/, "")
    .replace(/\s*(?:[A-Za-z]{1,3}\$?|[$€£¥])$/, "")
    .trim()
    .replace(/(?<=\d) (?=\d{3}(?:[ ,.]|$))/g, "");

  const cents = parseMoneyToken(stripped);
  if (cents === null) {
    return null;
  }
  return negative ? -cents : cents;
}

function parseMoneyToken(token: string): number | null {
  if (!/^\d(?:[\d.,]*\d)?$/.test(token)) {
    return null;
  }
  const hasDot = token.includes(".");
  const hasComma = token.includes(",");
  if (!hasDot && !hasComma) {
    return Number(token) * 100;
  }
  if (hasDot && hasComma) {
    const lastDot = token.lastIndexOf(".");
    const lastComma = token.lastIndexOf(",");
    const decSep = lastDot > lastComma ? "." : ",";
    const thouSep = decSep === "." ? "," : ".";
    if (token.indexOf(decSep) !== token.lastIndexOf(decSep)) {
      return null;
    }
    const [whole, fraction] = token.split(decSep);
    const escapedThou = thouSep === "." ? "\\." : ",";
    const thouPattern = new RegExp(`^\\d{1,3}(?:${escapedThou}\\d{3})+$`);
    if (!thouPattern.test(whole) || !/^\d{1,2}$/.test(fraction)) {
      return null;
    }
    const dollars = Number(whole.split(thouSep).join(""));
    const cents = Number((fraction + "00").slice(0, 2));
    return dollars * 100 + cents;
  }

  const sep = hasDot ? "." : ",";
  const parts = token.split(sep);
  if (parts.length > 2) {
    const escapedSep = sep === "." ? "\\." : ",";
    const thouPattern = new RegExp(`^\\d{1,3}(?:${escapedSep}\\d{3})+$`);
    if (!thouPattern.test(token)) {
      return null;
    }
    return Number(parts.join("")) * 100;
  }

  const [left, right] = parts;
  if (!/^\d+$/.test(left) || !/^\d+$/.test(right)) {
    return null;
  }
  if (right.length <= 2) {
    return Number(left) * 100 + Number((right + "00").slice(0, 2));
  }
  if (right.length === 3 && left.length <= 3 && !left.startsWith("0")) {
    return Number(left + right) * 100;
  }
  return null;
}

function normalizeCurrency(raw: string | null): string | null {
  if (!raw) {
    return null;
  }
  const upper = raw.trim().toUpperCase();
  if (upper === "RM") return "MYR";
  if (upper === "NZ$") return "NZD";
  if (upper === "A$" || upper === "AU$") return "AUD";
  if (upper === "US$") return "USD";
  if (upper === "S$" || upper === "SG$") return "SGD";
  if (upper === "HK$") return "HKD";
  if (upper === "€") return "EUR";
  if (upper === "£") return "GBP";
  if (upper === "RMB") return "CNY";
  return upper;
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
