import { Socket } from "phoenix";

export class AudioCapture {
  constructor(eventUuid, audioToken) {
    this.eventUuid = eventUuid;
    this.audioToken = audioToken;
    this.socket = null;
    this.channel = null;
    this.stream = null;
    this.audioContext = null;
    this.workletNode = null;
  }

  async start(deviceId) {
    try {
      const audioConstraints = deviceId
        ? { deviceId: { exact: deviceId } }
        : true;
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: audioConstraints,
      });

      this.socket = new Socket("/audio", {
        params: { token: this.audioToken },
      });
      this.socket.connect();

      this.channel = this.socket.channel(`audio:${this.eventUuid}`, {});
      this.channel
        .join()
        .receive("ok", () => {
          console.log("Joined audio channel");
          this.startPCMCapture();
        })
        .receive("error", (resp) => {
          console.error("Unable to join audio channel", resp);
        });
    } catch (err) {
      console.error("Failed to start audio capture:", err);
    }
  }

  async startPCMCapture() {
    this.audioContext = new AudioContext({ sampleRate: 48000 });
    const source = this.audioContext.createMediaStreamSource(this.stream);

    await this.audioContext.audioWorklet.addModule("/worklets/pcm-processor.js");
    this.workletNode = new AudioWorkletNode(
      this.audioContext,
      "pcm-processor",
    );

    this.workletNode.port.onmessage = (event) => {
      if (this.channel) {
        const bytes = new Uint8Array(event.data);
        const base64 = btoa(String.fromCharCode(...bytes));
        this.channel.push("audio_chunk", { data: base64 });
      }
    };

    source.connect(this.workletNode);
    this.workletNode.connect(this.audioContext.destination);
  }

  stop() {
    if (this.workletNode) {
      this.workletNode.disconnect();
      this.workletNode = null;
    }
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    if (this.channel) {
      this.channel.leave();
      this.channel = null;
    }
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
}
