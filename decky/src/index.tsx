import {
  ButtonItem,
  DropdownItem,
  Field,
  PanelSection,
  PanelSectionRow,
  SliderField,
  ToggleField,
  staticClasses,
} from "@decky/ui";
import { callable, definePlugin, useQuickAccessVisible } from "@decky/api";
import { useCallback, useEffect, useRef, useState } from "react";
import { FaHeadphones } from "react-icons/fa";

// ---- Backend bridge (main.py) ------------------------------------------------

interface Battery { present: boolean; level: number; charging: string }
interface Status {
  phase: string;
  connected: boolean;
  device: { name: string; model: string; firmware: string; codec: string };
  battery: { main: Battery; left: Battery; right: Battery; case: Battery };
  capabilities: Record<string, boolean>;
  noise: { mode: string; ambient_level: number; focus_on_voice: boolean };
  speak_to_chat: { enabled: boolean };
  equalizer: { preset: string; available_presets: string[]; dsee_enabled: boolean };
  playback: { volume: number };
  connection: { priority: string };
  last_error: string;
}

const getStatus = callable<[], { ok: boolean; status: Status | null; error: string }>("status");
const sendCommand = callable<[words: string[]], { ok: boolean; error: string }>("command");

// ---- Labels (mirrors the upstream Model.js) ----------------------------------

const PHASES: Record<string, string> = {
  discovering: "Discovering", connecting: "Connecting", syncing: "Synchronizing",
  ready: "Connected", error: "Connection error",
};
const PRESETS: Record<string, string> = {
  off: "Off", rock: "Rock", pop: "Pop", jazz: "Jazz", dance: "Dance", edm: "EDM",
  r_and_b_hip_hop: "R&B / Hip-Hop", acoustic: "Acoustic", bright: "Bright", excited: "Excited",
  mellow: "Mellow", relaxed: "Relaxed", vocal: "Vocal", treble: "Treble Boost", bass: "Bass Boost",
  speech: "Speech", heavy: "Heavy", clear: "Clear", hard: "Hard", soft: "Soft", gaming: "Gaming",
  fps_1: "FPS 1", fps_2: "FPS 2", fps_3: "FPS 3", custom: "Custom",
  user_1: "User 1", user_2: "User 2", user_3: "User 3", user_4: "User 4", user_5: "User 5",
};
const CODECS: Record<string, string> = {
  sbc: "SBC", aac: "AAC", ldac: "LDAC", aptx: "aptX", aptx_hd: "aptX HD", lc3: "LC3",
};

function batteryText(b: Battery): string {
  const level = b.level < 0 ? "--" : `${b.level}%`;
  if (b.charging === "yes") return `${level} · Charging`;
  if (b.charging === "complete") return `${level} · Charged`;
  return level;
}

// ---- Hooks -------------------------------------------------------------------

const POLL_MS = 1000;
const SETTLE_MS = 1500; // keep a just-set slider value until the device echoes it

/** Holds the control session open and polls status only while the QAM is visible. */
function useHeadphones(active: boolean) {
  const [status, setStatus] = useState<Status | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;

    const poll = async () => {
      try {
        const res = await getStatus();
        if (cancelled) return;
        setStatus(res.status);
        setError(res.ok ? "" : res.error);
      } catch (e) {
        if (!cancelled) setError(String(e));
      }
      if (!cancelled) timer = setTimeout(poll, POLL_MS);
    };

    sendCommand(["panel-open"]).then((res) => {
      if (!cancelled && !res.ok) setError(res.error);
    });
    poll();

    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
      // Release RFCOMM (after the daemon's idle delay) so Sony's phone app can reconnect.
      sendCommand(["panel-close"]);
    };
  }, [active]);

  return { status, error, setError };
}

/** A slider value that follows the device but doesn't snap back mid-adjustment. */
function useSettledValue(remote: number, send: (v: number) => void) {
  const [local, setLocal] = useState<number | null>(null);
  const sendTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const settleTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => () => {
    clearTimeout(sendTimer.current);
    clearTimeout(settleTimer.current);
  }, []);

  const onChange = useCallback((v: number) => {
    setLocal(v);
    clearTimeout(sendTimer.current);
    clearTimeout(settleTimer.current);
    sendTimer.current = setTimeout(() => {
      send(v);
      settleTimer.current = setTimeout(() => setLocal(null), SETTLE_MS);
    }, 200);
  }, [send]);

  return [local ?? remote, onChange] as const;
}

// ---- UI ----------------------------------------------------------------------

function Controls({ status, run }: { status: Status; run: (w: string[]) => void }) {
  const caps = status.capabilities;
  const [ambient, setAmbient] = useSettledValue(
    status.noise.ambient_level, useCallback((v: number) => run(["ambient-level", String(v)]), [run]));
  const [volume, setVolume] = useSettledValue(
    status.playback.volume, useCallback((v: number) => run(["volume", String(v)]), [run]));

  const noiseOptions = [
    { data: "off", label: "Off" },
    ...(caps.noise_cancelling ? [{ data: "anc", label: "Noise cancelling" }] : []),
    ...(caps.ambient_sound ? [{ data: "ambient", label: "Ambient sound" }] : []),
  ];
  const presets = status.equalizer.available_presets;
  const batteries = (["main", "left", "right", "case"] as const)
    .filter((k) => status.battery[k].present)
    .map((k) => ({ key: k, label: { main: "Battery", left: "Left", right: "Right", case: "Case" }[k] }));

  return (
    <>
      <PanelSection title="Status">
        {batteries.map(({ key, label }) => (
          <PanelSectionRow key={key}>
            <Field label={label} focusable={false}>{batteryText(status.battery[key])}</Field>
          </PanelSectionRow>
        ))}
        <PanelSectionRow>
          <Field label="Codec" focusable={false}>{CODECS[status.device.codec] ?? "Unknown"}</Field>
        </PanelSectionRow>
      </PanelSection>

      {(caps.noise_cancelling || caps.ambient_sound) && (
        <PanelSection title="Noise control">
          <PanelSectionRow>
            <DropdownItem
              label="Mode"
              rgOptions={noiseOptions}
              selectedOption={status.noise.mode}
              onChange={(o) => run(["noise", o.data])}
            />
          </PanelSectionRow>
          {caps.ambient_sound && status.noise.mode === "ambient" && (
            <>
              <PanelSectionRow>
                <SliderField label="Ambient level" value={ambient} min={1} max={20} step={1}
                  showValue onChange={setAmbient} />
              </PanelSectionRow>
              <PanelSectionRow>
                <ToggleField label="Focus on voice" checked={status.noise.focus_on_voice}
                  onChange={(on) => run(["focus-on-voice", on ? "on" : "off"])} />
              </PanelSectionRow>
            </>
          )}
          {caps.speak_to_chat && (
            <PanelSectionRow>
              <ToggleField label="Speak-to-Chat" checked={status.speak_to_chat.enabled}
                onChange={(on) => run(["speak-to-chat", on ? "on" : "off"])} />
            </PanelSectionRow>
          )}
        </PanelSection>
      )}

      {(presets.length > 0 || caps.equalizer || caps.dsee || caps.playback_volume) && (
        <PanelSection title="Sound">
          {caps.playback_volume && (
            <PanelSectionRow>
              <SliderField label="Headphone volume" value={volume} min={0} max={100} step={1}
                showValue onChange={setVolume} />
            </PanelSectionRow>
          )}
          {presets.length === 0 && caps.equalizer && status.equalizer.preset !== "unknown" && (
            <PanelSectionRow>
              <Field label="Equalizer" focusable={false}>
                {PRESETS[status.equalizer.preset] ?? status.equalizer.preset}
              </Field>
            </PanelSectionRow>
          )}
          {presets.length > 0 && (
            <PanelSectionRow>
              <DropdownItem
                label="Equalizer"
                rgOptions={presets.map((p) => ({ data: p, label: PRESETS[p] ?? p }))}
                selectedOption={status.equalizer.preset}
                onChange={(o) => run(["eq-preset", o.data])}
              />
            </PanelSectionRow>
          )}
          {caps.dsee && (
            <PanelSectionRow>
              <ToggleField label="DSEE" checked={status.equalizer.dsee_enabled}
                onChange={(on) => run(["dsee", on ? "on" : "off"])} />
            </PanelSectionRow>
          )}
        </PanelSection>
      )}

      {caps.connection_mode && (
        <PanelSection title="Connection">
          <PanelSectionRow>
            <DropdownItem
              label="Priority"
              rgOptions={[
                { data: "quality", label: "Sound quality" },
                { data: "stable", label: "Stable connection" },
              ]}
              selectedOption={status.connection.priority}
              onChange={(o) => run(["connection", o.data])}
            />
          </PanelSectionRow>
        </PanelSection>
      )}
    </>
  );
}

function Content() {
  const visible = useQuickAccessVisible();
  const { status, error, setError } = useHeadphones(visible);

  const run = useCallback((words: string[]) => {
    sendCommand(words).then((res) => setError(res.ok ? "" : res.error));
  }, [setError]);

  const ready = status?.connected && status.phase === "ready";
  const title = status?.device.model || status?.device.name || "Sony Headphones";
  const shownError = error || status?.last_error || "";

  return (
    <>
      <PanelSection title={title}>
        <PanelSectionRow>
          <Field label="State" focusable={false}>
            {status ? PHASES[status.phase] ?? "Idle" : "Waiting for service"}
          </Field>
        </PanelSectionRow>
        {shownError && (
          <PanelSectionRow>
            <div style={{ color: "#ff8a80", fontSize: "12px", padding: "4px 0", wordBreak: "break-word" }}>
              {shownError}
            </div>
          </PanelSectionRow>
        )}
        {!ready && (
          <PanelSectionRow>
            <div style={{ fontSize: "12px", opacity: 0.7, padding: "4px 0" }}>
              Connect your headphones over Bluetooth, then keep this panel open while the control
              channel initializes.
            </div>
          </PanelSectionRow>
        )}
        {ready && (
          <PanelSectionRow>
            <ButtonItem layout="below" onClick={() => run(["refresh"])}>Refresh</ButtonItem>
          </PanelSectionRow>
        )}
      </PanelSection>
      {ready && status && <Controls status={status} run={run} />}
    </>
  );
}

export default definePlugin(() => ({
  name: "Sony Headphones",
  titleView: <div className={staticClasses.Title}>Sony Headphones</div>,
  content: <Content />,
  icon: <FaHeadphones />,
  onDismount() {
    sendCommand(["panel-close"]);
  },
}));
