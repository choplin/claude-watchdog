import { parseArgs } from "util";
import { reconcile } from "../reconcile";
import type { OutputFormat } from "../types";

export function runReconcile(args: string[]): void {
  const { values } = parseArgs({
    args,
    options: {
      format: { type: "string", default: "text" },
    },
  });

  const format = values.format as OutputFormat;
  const result = reconcile();

  if (format === "json") {
    console.log(JSON.stringify(result, null, 2));
  } else {
    if (result.deleted.length === 0) {
      console.log("No stale sessions found");
    } else {
      console.log(
        `Reconciled ${result.deleted.length} stale session(s)`
      );
    }
  }
}
