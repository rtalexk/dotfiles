import type { Plugin } from "@opencode-ai/plugin";
import { createDemuxHooks } from "../lib/demux-hooks";

declare const Bun: {
  spawn(command: string[], options: { stderr: "ignore"; stdout: "ignore" }): unknown;
};

const plugin: Plugin = async () =>
  createDemuxHooks((command) => {
    Bun.spawn(["/bin/zsh", "-lc", command], {
      stderr: "ignore",
      stdout: "ignore",
    });
  });

export default plugin;
