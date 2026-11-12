import assert from "node:assert/strict";
import test from "node:test";

import { entitiesToReceipt, moneyToCents } from "./receipt_extraction_service.ts";

test("money uses the first two decimal digits", () => {
  assert.equal(moneyToCents("15.9"), 1590);
  assert.equal(moneyToCents("$1,234.56"), 123456);
  assert.equal(moneyToCents("not a price"), null);
});

test("expense fields keep the highest-confidence value", () => {
  const extracted = entitiesToReceipt([
    { type: "supplier_name", mentionText: "Wrong Cafe", confidence: 0.2 },
    { type: "supplier_name", mentionText: "Morning Cafe", confidence: 0.91 },
    {
      type: "receipt_date",
      mentionText: "12/11/2026",
      normalizedValue: { text: "2026-11-12" },
      confidence: 0.8,
    },
    { type: "total_amount", normalizedValue: { text: "18.50" }, confidence: 0.97 },
    { type: "total_tax_amount", mentionText: "2.41", confidence: 0.7 },
    { type: "currency", normalizedValue: { text: "NZD" }, confidence: 0.99 },
  ]);

  assert.deepEqual(extracted, {
    merchant: "Morning Cafe",
    purchasedOn: "2026-11-12",
    totalCents: 1850,
    taxCents: 241,
    currency: "NZD",
    receiptNumber: null,
  });
});
