export interface PaneInfo {
  terminal: string; // "tmux", "wez"
  paneId: string; // raw pane ID
}

type Detector = () => PaneInfo | null;

// Add new terminals here. First match wins.
const detectors: Detector[] = [
  () => {
    const v = process.env.TMUX_PANE;
    return v ? { terminal: "tmux", paneId: v } : null;
  },
  () => {
    const v = process.env.WEZTERM_PANE;
    return v ? { terminal: "wez", paneId: v } : null;
  },
];

export function detectPane(): PaneInfo | null {
  for (const detect of detectors) {
    const result = detect();
    if (result) return result;
  }
  return null;
}

export function formatPane(session: {
  pane_id: string | null;
  pane_terminal: string | null;
}): string {
  if (session.pane_id && session.pane_terminal) {
    return `${session.pane_terminal}:${session.pane_id}`;
  }
  return "-";
}
