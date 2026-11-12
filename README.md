# TracePay

Receipt and expense tracker for people who need the original file later, not just a total.

People keep receipts in email, camera rolls, and folders. Months later it is hard to find the original, remember what the purchase was for, and see the GST they meant to claim. TracePay keeps the file with the details.

## Who it is for

- GST-registered self-employed people, such as sole traders and freelancers
- Self-employed people who are not GST-registered
- Salaried employees

## V1

Build the functions first. V1 has no monthly receipt cap. A cap can be added later if usage needs one.

1. Scan or upload a receipt, then review and save it.
2. Find an old receipt by merchant, receipt number, or date, and open the original file.
3. See spending by category for a period.
4. Mark a receipt as personal, business, or mixed. A mixed receipt keeps one file and lists the business items.
5. For GST-registered users, record the GST shown on the receipt separately from the amount they intend to claim. Uncertain amounts can be marked **Needs review**.
6. Export a date range as a business expense summary plus the original files. Amounts that need review stay separate from confirmed amounts.

Manual entry is always available. The user confirms or corrects every scanned field before it is saved.

### Later (V2)

- AI auto-tagging
- Receipt translation
- Currency conversion

## How a receipt is saved

The phone reads the receipt before anything is sent to a paid parser.

1. The user takes a photo or picks an image or PDF. The app compresses photos on the device and hashes the file.
2. Google ML Kit runs on the phone: text recognition, a simple image-quality check, and an instant preview. A small parser looks for merchant, date, and total from the text and its position on the page. PDFs that already contain real text are read locally first. A scanned PDF is rendered to an image and then read the same way.
3. If merchant, date, and total are present and look reliable, the user confirms them. That receipt is stored with the original file and is not sent to Document AI.
4. If those fields are missing or uncertain, or the user asks for line items on a mixed receipt, the app sends the file through TracePay's backend. The backend calls Google Document AI's Expense Parser. The Flutter app never calls Google directly. Swapping the parser means changing the class behind `ReceiptExtractionService` on the Worker.
5. The user reviews the result, fills gaps, chooses a category, and saves.

The Expense Parser returns merchant, date, amounts, tax, and line items. It does not reliably return a receipt number, so that field stays for the user to fill.

### Upload, storage, and processing

The original file goes to a private Cloudflare R2 bucket. PostgreSQL stores the object key, never a public URL.

1. The signed-in app asks the Worker for an upload. The Worker checks the Firebase ID token, file type, and size, and checks the file hash for a duplicate. The Worker chooses the object key. The user cannot pick another user's key.
2. The app uploads straight to R2 with a short-lived signed URL.
3. The app tells the Worker the upload finished. The Worker checks the object, then either saves the locally confirmed details or enqueues a processing job.
4. A Queue consumer runs Document AI only for jobs that need it, then writes the fields back. A scheduled Worker clears abandoned uploads.
5. Opening or downloading a file asks the Worker for a short-lived signed download URL. The Worker checks that the row belongs to the signed-in user before it signs the URL.

### Duplicates

- The same file is caught by a hash stored per user, before a second upload or a second parse.
- A queue retry uses the processing job so Document AI is not called again for a job that already succeeded.
- A second photo of the same paper receipt can still differ byte for byte. After extraction, the app warns when the same user already has a receipt with the same date and total. It does not block the save.

## Stack

| Piece | Choice |
| --- | --- |
| Mobile | Flutter (iOS and Android) |
| On-device text | Google ML Kit |
| API | Cloudflare Workers |
| Receipt files | Cloudflare R2 (private) |
| Background parsing | Cloudflare Queues, plus a scheduled Worker for cleanup |
| Database | Supabase (PostgreSQL) |
| Sign-in | Firebase Authentication (Apple and Google). The Worker verifies the Firebase ID token. |
| Cloud parse | Google Document AI Expense Parser, behind `ReceiptExtractionService` |
| Domain | `tracepay.app` on Cloudflare DNS (Free plan) |

Workers runs on the Paid plan ($5/month). R2 is usage-based and includes a free monthly allowance. Cloudflare Pro or Business is not required to start.

Early on, a few hundred users fit inside the Workers request allowance and the R2 free storage allowance if photos are compressed. Document AI is the cost that grows, at about $0.10 per receipt sent to the Expense Parser. Local ML Kit is what keeps that bill down. Firebase sign-in stays on its free tier at this size. Supabase is the database; start on its free tier and move up when backups and always-on compute matter.

## Data

Supabase holds the records. Every user-owned table has `user_id`.

- `users` — account, linked to the Firebase user id
- `user_settings` — currency, locale, GST registration, other preferences
- `subscriptions` — later premium plans
- `categories` — the user's categories
- `receipts` — merchant, date, totals, GST, usage (personal, business, or mixed), file key, file hash, how the fields were extracted
- `receipt_items` — business lines on a mixed receipt
- `processing_jobs` — queued, running, succeeded, or failed cloud parses
- `audit_logs` — important account and data changes

`receipt_items` and `processing_jobs` store `user_id` themselves, with a foreign key back to that user's receipt, so a line item cannot point at someone else's receipt.

Row Level Security is enabled and forced on every user-owned table. The Worker sets `app.user_id` from the verified Firebase token inside each database transaction. It never takes that id from a request body or query string. Policies use that setting for reads and writes. If it is missing, the database returns no rows and rejects writes. Connections use a role that cannot bypass RLS, and the setting is transaction-local so a pooled connection cannot carry one user into the next request. The same rules apply to receipt items, categories, and processing jobs.

## Repository

```
mobile/     Flutter app
worker/     Cloudflare Worker (extract API and the OCR boundary)
website/    Public site for tracepay.app
```

The scan screen, Supabase schema, ML Kit parser, signed R2 uploads, and Queues are the V1 work still to build. What is already in the repo:

- `mobile/lib/features/receipt.dart` — receipt fields kept on the phone for now
- `mobile/lib/core/network.dart` — calls the Worker's `/extract` endpoint only
- `worker/src/receipt_extraction_service.ts` — OCR interface
- `worker/src/google_document_ai_expense_parser.ts` — the current parser behind that interface

### Run the app

```bash
cd mobile
flutter pub get
flutter run
```

### Run the Worker locally

```bash
cd worker
cp .dev.vars.example .dev.vars
npm install
npm run dev
```

Fill `.dev.vars` with `API_TOKEN` and the Document AI project, location, processor, and access token before a cloud parse will succeed. Put the same `API_TOKEN` in `TracePayConfig` (`mobile/lib/core/config.dart`). The local API is `http://127.0.0.1:8787`. Production is `https://api.tracepay.app` after the domain is on Cloudflare and the Worker route in `worker/wrangler.toml` is enabled.
