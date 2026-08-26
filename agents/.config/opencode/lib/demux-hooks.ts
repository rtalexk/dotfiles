import type { Hooks } from "@opencode-ai/plugin";

export type RunCommand = (command: string) => void;
type LifecycleEvent = { type: string; properties: unknown };
type State = "working" | "waiting" | "done" | "error";

const tool = "opencode";
const MAX_MESSAGE = 400;

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function sanitize(message: string): string {
  const flat = message.replace(/\s+/g, " ").trim();
  return flat.length > MAX_MESSAGE ? `${flat.slice(0, MAX_MESSAGE)}…` : flat;
}

function stateCommand(state: State, message: string, hook: string, force = false): string {
  const options = force ? " --force" : "";
  const completionOption = state === "done" || state === "error" ? " --set-state-error" : "";
  const quoted = shellQuote(sanitize(message));

  return `demux state set --target-id "$TMUX_PANE" --state ${state} --tool ${tool} --message ${quoted}${options} || demux event hook_error --hook ${hook} --tool ${tool} --target-id "$TMUX_PANE" --message ${shellQuote(`state set failed: ${sanitize(message)}`)}${completionOption}`;
}

function sessionID(event: { properties: unknown }): string | undefined {
  if (typeof event.properties !== "object" || event.properties === null) {
    return undefined;
  }

  const { sessionID } = event.properties as { sessionID?: unknown };
  return typeof sessionID === "string" ? sessionID : undefined;
}

function isBusy(event: LifecycleEvent): boolean {
  if (typeof event.properties !== "object" || event.properties === null) {
    return false;
  }

  const { status } = event.properties as { status?: unknown };
  if (typeof status !== "object" || status === null) {
    return false;
  }

  return (status as { type?: unknown }).type === "busy";
}

function errorMessage(event: LifecycleEvent): string {
  if (typeof event.properties !== "object" || event.properties === null) {
    return "task failed";
  }

  const { error } = event.properties as {
    error?: { name?: unknown; data?: { message?: unknown } };
  };
  const name = typeof error?.name === "string" ? error.name : "UnknownError";
  const detail = typeof error?.data?.message === "string" ? error.data.message : "";

  return detail ? `${name}: ${detail}` : name;
}

export function createDemuxHooks(runCommand: RunCommand): Hooks {
  let activeSessionID: string | undefined;
  let errored = false;

  function working(): void {
    runCommand(stateCommand("working", "on it", "OpenCode.working", true));
    errored = false;
  }

  function waiting(message: string, hook: string): void {
    runCommand(stateCommand("waiting", message, hook));
    runCommand("afplay /System/Library/Sounds/Ping.aiff >/dev/null 2>&1 &");
  }

  function failed(message: string, hook: string): void {
    runCommand(stateCommand("error", message, hook, true));
    runCommand("afplay /System/Library/Sounds/Submarine.aiff >/dev/null 2>&1 &");
    errored = true;
  }

  function done(): void {
    runCommand(stateCommand("done", "task complete", "OpenCode.session.idle"));
    runCommand("afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &");
  }

  return {
    "chat.message": async (input) => {
      activeSessionID = input.sessionID;
      working();
    },
    "tool.execute.before": async (input) => {
      if (input.sessionID === activeSessionID) {
        working();
      }
    },
    event: async ({ event }) => {
      const lifecycleEvent = event as unknown as LifecycleEvent;
      const eventSessionID = sessionID(lifecycleEvent);
      const isErrorEvent = lifecycleEvent.type === "session.error";

      // session.error may omit sessionID; it still belongs to the active pane.
      if (eventSessionID !== activeSessionID && !(isErrorEvent && eventSessionID === undefined)) {
        return;
      }

      switch (lifecycleEvent.type) {
        case "permission.asked":
        case "permission.v2.asked":
          waiting("awaiting permission", `OpenCode.${lifecycleEvent.type}`);
          break;
        case "question.asked":
        case "question.v2.asked":
          waiting("awaiting input", `OpenCode.${lifecycleEvent.type}`);
          break;
        case "session.error":
          failed(errorMessage(lifecycleEvent), "OpenCode.session.error");
          break;
        case "session.status":
          if (isBusy(lifecycleEvent)) {
            working();
          }
          break;
        case "session.idle":
          // Keep the error visible; idle always follows a failed turn.
          if (!errored) {
            done();
          }
          activeSessionID = undefined;
          errored = false;
          break;
      }
    },
  };
}
