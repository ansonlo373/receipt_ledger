import {CloudBillingClient} from "@google-cloud/billing";
import {onMessagePublished} from "firebase-functions/v2/pubsub";
import * as logger from "firebase-functions/logger";

/**
 * What a Cloud Billing budget publishes to its Pub/Sub topic. Only the two
 * amounts matter here; the rest of the payload is ignored.
 */
interface BudgetNotification {
  budgetDisplayName?: string;
  costAmount?: number;
  budgetAmount?: number;
  currencyCode?: string;
}

/**
 * Detaches the billing account from this project, which stops every billable
 * service until billing is manually re-enabled in the console.
 *
 * Deliberately drastic. This is a hobby project with no revenue, so a hard
 * stop is strictly better than an unbounded bill — the cost of being wrong is
 * an app that stops working, not money.
 */
export const billingKillSwitch = onMessagePublished(
  {topic: "billing-budget-alerts", region: "us-central1"},
  async (event) => {
    const notification = event.data.message.json as BudgetNotification;
    const cost = notification.costAmount ?? 0;
    const budget = notification.budgetAmount ?? 0;

    // Budgets also fire at 50% and 90%. Acting on those would cut the project
    // off at half the threshold, so only a genuine breach counts.
    if (budget <= 0 || cost < budget) {
      logger.info("Budget alert below threshold, taking no action", {
        cost,
        budget,
      });
      return;
    }

    const projectId = process.env.GCLOUD_PROJECT;
    if (!projectId) {
      logger.error("No project id available; cannot disable billing");
      return;
    }
    const projectName = `projects/${projectId}`;

    // Leave the safety net inert until it has been proven against a synthetic
    // alert — the real path cannot be rehearsed without actually spending the
    // money, and getting it wrong takes the whole project offline.
    if (process.env.BILLING_KILL_SWITCH_DRY_RUN === "true") {
      logger.warn("DRY RUN: would disable billing now", {
        projectName,
        cost,
        budget,
      });
      return;
    }

    const billing = new CloudBillingClient();
    const [info] = await billing.getProjectBillingInfo({name: projectName});
    if (!info.billingAccountName) {
      logger.info("Billing already disabled; nothing to do");
      return;
    }

    // An empty billing account name is what detaches it.
    await billing.updateProjectBillingInfo({
      name: projectName,
      projectBillingInfo: {billingAccountName: ""},
    });
    logger.warn("Billing DISABLED after budget breach", {
      projectName,
      cost,
      budget,
    });
  }
);
