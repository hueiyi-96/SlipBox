import {
  entitiesToReceipt,
  type ExtractedReceipt,
  type ReceiptEntity,
  type ReceiptExtractionService,
  type ReceiptFile,
} from "./receipt_extraction_service";

export type DocumentAiConfig = {
  project: string;
  location: string;
  processor: string;
  accessToken: string;
};

/** Google Document AI Expense Parser. This is the only file that calls Google. */
export class GoogleDocumentAiExpenseParser implements ReceiptExtractionService {
  constructor(private readonly config: DocumentAiConfig) {}

  async extract(file: ReceiptFile): Promise<ExtractedReceipt> {
    const { project, location, processor, accessToken } = this.config;
    if (!/^[a-z0-9-]+$/i.test(location)) {
      throw new Error("Document AI location is invalid");
    }
    const url =
      `https://${location}-documentai.googleapis.com/v1/` +
      `projects/${project}/locations/${location}/processors/${processor}:process`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        rawDocument: {
          content: bytesToBase64(file.bytes),
          mimeType: file.contentType,
        },
      }),
    });
    if (!response.ok) {
      throw new Error(`Document AI returned ${response.status}`);
    }
    const payload = (await response.json()) as {
      document?: { entities?: ReceiptEntity[] };
    };
    return entitiesToReceipt(payload.document?.entities ?? []);
  }
}

export function documentAiConfig(env: {
  DOCUMENT_AI_PROJECT?: string;
  DOCUMENT_AI_LOCATION?: string;
  DOCUMENT_AI_PROCESSOR?: string;
  DOCUMENT_AI_ACCESS_TOKEN?: string;
}): DocumentAiConfig | null {
  const project = env.DOCUMENT_AI_PROJECT?.trim();
  const location = env.DOCUMENT_AI_LOCATION?.trim();
  const processor = env.DOCUMENT_AI_PROCESSOR?.trim();
  const accessToken = env.DOCUMENT_AI_ACCESS_TOKEN?.trim();
  if (!project || !location || !processor || !accessToken) {
    return null;
  }
  return { project, location, processor, accessToken };
}

function bytesToBase64(bytes: ArrayBuffer): string {
  const view = new Uint8Array(bytes);
  let binary = "";
  for (const byte of view) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}
