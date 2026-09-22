// Persistence of the add-in configuration.
//
// PowerPoint content add-ins are embedded objects; each inserted instance has
// its own `Office.context.document.settings` bag, saved inside the .pptx.
// That is where the slide -> interaction mapping lives, so it survives
// close/reopen, duplicate slide and move slide.
//
// The server URL and the access token are also mirrored in localStorage so
// that the next inserted instance is pre-filled (the token never leaves the
// user's machine except to call their own server).
//
// NOTE: the exact persistence behaviour must be verified against the current
// PowerPoint builds during the sideload tests (see docs/office-addin.md).

export interface AddinConfig {
  serverUrl: string;
  token: string;
  eventId: string | null;
  interactionId: string | null; // "poll_12", "word_cloud_3", ... or "join_screen"
  eventName?: string;
}

const KEY = "openPresenter";
const LOCAL_KEY = "openPresenter.defaults";

function officeSettings(): Office.Settings | null {
  try {
    return Office?.context?.document?.settings ?? null;
  } catch (_e) {
    return null;
  }
}

export function loadConfig(): AddinConfig {
  const defaults: Partial<AddinConfig> = readLocal();
  const settings = officeSettings();
  const stored = settings ? (settings.get(KEY) as Partial<AddinConfig> | null) : null;

  return {
    serverUrl: stored?.serverUrl ?? defaults.serverUrl ?? defaultServerUrl(),
    token: stored?.token ?? defaults.token ?? "",
    eventId: stored?.eventId ?? null,
    interactionId: stored?.interactionId ?? null,
    eventName: stored?.eventName,
  };
}

export function saveConfig(config: AddinConfig): Promise<void> {
  writeLocal({ serverUrl: config.serverUrl, token: config.token });
  const settings = officeSettings();
  if (!settings) return Promise.resolve();

  settings.set(KEY, config);
  return new Promise((resolve, reject) => {
    settings.saveAsync((result) => {
      if (result.status === Office.AsyncResultStatus.Succeeded) resolve();
      else reject(new Error(result.error?.message ?? "Could not save settings"));
    });
  });
}

export function clearInteraction(config: AddinConfig): Promise<void> {
  return saveConfig({ ...config, interactionId: null });
}

export function defaultServerUrl(): string {
  // When served by Phoenix at https://host/office/, the server is the origin.
  const origin = window.location.origin;
  if (/localhost:3000$/.test(origin)) return "http://localhost:4000";
  return origin;
}

function readLocal(): Partial<AddinConfig> {
  try {
    return JSON.parse(localStorage.getItem(LOCAL_KEY) || "{}");
  } catch (_e) {
    return {};
  }
}

function writeLocal(values: Partial<AddinConfig>): void {
  try {
    localStorage.setItem(LOCAL_KEY, JSON.stringify({ ...readLocal(), ...values }));
  } catch (_e) {
    // storage may be unavailable inside some Office hosts
  }
}
