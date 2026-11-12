import { documentAiConfig, GoogleDocumentAiExpenseParser } from "./google_document_ai_expense_parser";
import type { ExtractedReceipt, ReceiptExtractionService } from "./receipt_extraction_service";

export interface Env {
  RECEIPTS: R2Bucket;
  API_TOKEN?: string;
  DOCUMENT_AI_PROJECT?: string;
  DOCUMENT_AI_LOCATION?: string;
  DOCUMENT_AI_PROCESSOR?: string;
  DOCUMENT_AI_ACCESS_TOKEN?: string;
}

const maxBytes = 8_000_000;
const allowedTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/extract") {
      return json({ error: "Not found" }, 404);
    }
    if (!tokenMatches(env.API_TOKEN, request.headers.get("authorization"))) {
      return json({ error: "Unauthorized" }, 401);
    }

    const contentType = mediaType(request.headers.get("content-type"));
    if (!allowedTypes.has(contentType)) {
      return json({ error: "Send a JPEG, PNG, WebP, or PDF receipt." }, 415);
    }

    const bytes = await request.arrayBuffer();
    if (bytes.byteLength === 0 || bytes.byteLength > maxBytes) {
      return json({ error: "Receipt file must be under 8 MB." }, 413);
    }

    const fileKey = `receipts/${crypto.randomUUID()}`;
    await env.RECEIPTS.put(fileKey, bytes, {
      httpMetadata: { contentType },
    });

    const config = documentAiConfig(env);
    if (!config) {
      return json({ fileKey, error: "Receipt extraction is not configured." }, 503);
    }

    try {
      const extracted = await extractionService(config).extract({ bytes, contentType });
      return json({ fileKey, ...extracted }, 200);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Receipt extraction failed";
      return json({ fileKey, error: message }, 502);
    }
  },
};

/** Swap the class here to change OCR providers. The Flutter app calls /extract either way. */
export function extractionService(config: NonNullable<ReturnType<typeof documentAiConfig>>): ReceiptExtractionService {
  return new GoogleDocumentAiExpenseParser(config);
}

function tokenMatches(expected: string | undefined, header: string | null): boolean {
  const token = expected?.trim();
  if (!token) {
    return false;
  }
  const provided = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
  if (provided.length !== token.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < token.length; i++) {
    mismatch |= token.charCodeAt(i) ^ provided.charCodeAt(i);
  }
  return mismatch === 0;
}

function mediaType(header: string | null): string {
  return (header ?? "").split(";")[0].trim().toLowerCase();
}

function json(body: Record<string, unknown> | (ExtractedReceipt & { fileKey: string }), status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
