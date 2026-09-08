import {GoogleGenAI, Type} from "@google/genai";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Which model reads the receipts.
 *
 * Overridable without a code change, because model names move quickly and
 * this is the one setting most likely to need swapping. A full "flash" model
 * rather than "flash-lite": this path exists precisely because on-device OCR
 * misread messy receipts, so reading quality is the point, and the difference
 * in cost is a fraction of a cent per scan.
 */
const MODEL = process.env.GEMINI_MODEL ?? "gemini-3.5-flash";

/**
 * Asking for JSON in the prompt alone invites markdown fences and prose
 * around the answer. Declaring the shape makes the model return parseable
 * JSON directly, which removes a whole class of extraction bugs.
 */
const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    merchant: {
      type: Type.STRING,
      description: "Shop or company name. Empty string if unreadable.",
    },
    amount: {
      type: Type.INTEGER,
      description:
        "Total actually paid, in whole yen, digits only. 0 if unreadable.",
    },
    date: {
      type: Type.STRING,
      description:
        "Date printed on the receipt as YYYY-MM-DD. Empty string if absent.",
    },
  },
  required: ["merchant", "amount", "date"],
};

const PROMPT = `You are reading a photographed shop receipt, usually Japanese.

Extract exactly three things:
- merchant: the shop or company name, normally the largest text at the top.
  Prefer the brand over a branch or location name.
- amount: the total the customer actually paid, in whole yen. This is the
  figure next to 合計, お買上げ, or "total" — not a subtotal, not tax, not an
  item price, not points or change. Digits only, no currency symbol or commas.
  Note that OCR often confuses the ¥ symbol with a digit or letter, so a
  leading character that makes the total implausibly large is likely a
  misread ¥.
- date: the date printed on the receipt, as YYYY-MM-DD. This is the purchase
  date, not today.

If something genuinely cannot be read, return an empty string (or 0 for
amount) rather than guessing.`;

interface RescanRequest {
  imageBase64?: string;
}

/**
 * Reads a receipt photo with Gemini and returns the fields it found.
 *
 * A callable function rather than a plain HTTPS one so Firebase Auth checks
 * the caller's token for us — the key stays server-side and only signed-in
 * users can spend it.
 */
export const rescanReceipt = onCall<RescanRequest>(
  {region: "us-central1", memory: "512MiB", timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before scanning a receipt."
      );
    }

    const imageBase64 = request.data?.imageBase64;
    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "No image was sent.");
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      logger.error("GEMINI_API_KEY is not set");
      throw new HttpsError("failed-precondition", "Scanning is unavailable.");
    }

    const ai = new GoogleGenAI({apiKey});
    try {
      const response = await ai.models.generateContent({
        model: MODEL,
        contents: [
          {
            role: "user",
            parts: [
              {inlineData: {mimeType: "image/jpeg", data: imageBase64}},
              {text: PROMPT},
            ],
          },
        ],
        config: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          // Reading what is printed is not a creative task; the lowest
          // setting keeps repeated scans of one receipt consistent.
          temperature: 0,
        },
      });

      const text = response.text;
      if (!text) throw new Error("Empty response from the model");

      const parsed = JSON.parse(text);
      logger.info("Receipt read", {uid: request.auth.uid, model: MODEL});
      return {
        merchant: parsed.merchant ?? "",
        amount: parsed.amount ?? 0,
        date: parsed.date ?? "",
      };
    } catch (error) {
      logger.error("Gemini rescan failed", {error: String(error)});
      throw new HttpsError("internal", "Could not read the receipt.");
    }
  }
);
