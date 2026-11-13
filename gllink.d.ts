// GL-Link's extension API, host_api 1: what an app extension's script can call.
// Written by `gllink-ext new`; `gllink-ext types` prints the current one.
//
// A script runs in JavaScriptCore: modern JavaScript, but no DOM, no Node, and nothing
// but what's declared here.

interface GLLinkRouter {
  /** GL-Link's id for the router on this device. */
  id: string;
  /** As the person named it. */
  name: string;
  /** Milliseconds since 1970 when it last answered, or null. */
  updated: number | null;
  /** With the "battery" permission, on routers that have one. */
  battery?: { level: number; charging: boolean };
  /** With the "model" permission. */
  model?: { id: string; code: string; name: string; symbol: string | null };
}

interface GLLinkAction {
  id: string;
  /** A short verb in title case: "Read Now". */
  title: string;
  /** "destructive" draws it red. */
  role?: "destructive";
  /** A sentence asked before it runs. */
  confirm?: string;
}

interface GLLinkSocket {
  send(text: string): Promise<void>;
  close(): void;
  onmessage: ((event: { data: string }) => void) | null;
  onclose: ((event: { reason: string }) => void) | null;
}

interface GLLinkResponse {
  status: number;
  ok: boolean;
  text(): Promise<string>;
  json(): Promise<any>;
}

interface GLLink {
  /** The paired routers, as far as the manifest's `routers` permission allows. */
  routers(): GLLinkRouter[];
  /** Reads every router again. */
  refresh(): Promise<void>;
  /** What it can see of the routers changed. Can be every few seconds. */
  on(event: "routers", handler: () => void): void;
  /** One of its actions was tapped, and confirmed if it asks. */
  on(event: "action", handler: (id: string) => void | Promise<void>): void;
  /** It's being turned off or removed: close what you opened. */
  on(event: "stop", handler: () => void): void;
  /** The line under its name in Settings; up to 200 characters. */
  status(text: string): void;
  /** Rows under it in Settings, up to 20. Replaces the last ones. */
  show(rows: { title: string; value: string }[]): void;
  /** Buttons under it, up to 8. Replaces the last ones. */
  actions(actions: GLLinkAction[]): void;
  /** A file named in the manifest's `files`, as text, or null. */
  readFile(path: string): string | null;
  /** A file inside its own package (up to 1 MB), as text or base64, or null. */
  resource(path: string, encoding?: "utf8" | "base64"): string | null;
  /** Its own secrets, kept in the Keychain. `set(key, null)` removes one. */
  secrets: { get(key: string): string | null; set(key: string, value: string | null): void };
  /** A WebSocket to a host in the manifest's `network`. */
  connect(url: string): GLLinkSocket;
  app: { platform: "ios" | "macos"; bundleID: string; version: string };
}

declare const gllink: GLLink;

/** HTTP to a host in the manifest's `network`. Text bodies; 10 s timeout. */
declare function fetch(
  url: string,
  options?: { method?: string; headers?: Record<string, string>; body?: string },
): Promise<GLLinkResponse>;

declare function setTimeout(handler: () => void, ms?: number): number;
declare function setInterval(handler: () => void, ms?: number): number;
declare function clearTimeout(id: number): void;
declare function clearInterval(id: number): void;
declare const console: {
  log(...args: any[]): void;
  info(...args: any[]): void;
  warn(...args: any[]): void;
  error(...args: any[]): void;
};
