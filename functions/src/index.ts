// Cloud Functions for receipt_ledger.
//
// A billing kill-switch used to live here (see git history): a budget alert
// published to Pub/Sub, and a function that detached the project's billing
// account when spend crossed $1. It was dropped deliberately. Disabling
// billing can take project resources with it, and an automated process that
// can delete your data is a worse risk than the small bill it guards against.
// The $1 budget remains as an email alert instead.
export {};
