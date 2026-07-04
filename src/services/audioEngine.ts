/**
 * Web Audio Engine for Walkie-Talkie Radio FX and Microphone Spectrum Analyzer
 */

class AudioEngine {
  private ctx: AudioContext | null = null;
  private micStream: MediaStream | null = null;
  private analyser: AnalyserNode | null = null;
  private micSource: MediaStreamAudioSourceNode | null = null;
  private isMicActive = false;
  private soundEnabled = true;

  private getContext(): AudioContext {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      this.ctx = new AudioCtx();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
    return this.ctx;
  }

  public setSoundEnabled(enabled: boolean) {
    this.soundEnabled = enabled;
  }

  public isEnabled(): boolean {
    return this.soundEnabled;
  }

  /**
   * Play Walkie-Talkie Press Squelch / Mic Click
   */
  public playPttPressSound() {
    if (!this.soundEnabled) return;
    try {
      const ctx = this.getContext();
      const now = ctx.currentTime;

      // 1. White noise squelch burst (radio static)
      const bufferSize = ctx.sampleRate * 0.05; // 50ms
      const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) {
        data[i] = (Math.random() * 2 - 1) * 0.2;
      }

      const noise = ctx.createBufferSource();
      noise.buffer = buffer;

      // Filter noise
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.setValueAtTime(1500, now);
      filter.Q.setValueAtTime(3, now);

      const noiseGain = ctx.createGain();
      noiseGain.gain.setValueAtTime(0.15, now);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.045);

      noise.connect(filter);
      filter.connect(noiseGain);
      noiseGain.connect(ctx.destination);

      noise.start(now);

      // 2. High frequency radio beep
      const osc = ctx.createOscillator();
      const oscGain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(1100, now);
      osc.frequency.exponentialRampToValueAtTime(1400, now + 0.03);

      oscGain.gain.setValueAtTime(0.12, now);
      oscGain.gain.exponentialRampToValueAtTime(0.001, now + 0.035);

      osc.connect(oscGain);
      oscGain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.04);
    } catch (err) {
      console.warn('Audio play error:', err);
    }
  }

  /**
   * Play Walkie-Talkie Release Roger Beep (Over and Out double chirp)
   */
  public playPttReleaseSound() {
    if (!this.soundEnabled) return;
    try {
      const ctx = this.getContext();
      const now = ctx.currentTime;

      // Chirp 1: 1250 Hz
      const osc1 = ctx.createOscillator();
      const gain1 = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(1250, now);

      gain1.gain.setValueAtTime(0.15, now);
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.045);

      // Chirp 2: 950 Hz after 50ms
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(950, now + 0.05);

      gain2.gain.setValueAtTime(0.18, now + 0.05);
      gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.1);

      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(now + 0.05);
      osc2.stop(now + 0.11);

      // Final radio static pop
      const bufferSize = ctx.sampleRate * 0.03;
      const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) {
        data[i] = (Math.random() * 2 - 1) * 0.15;
      }
      const noise = ctx.createBufferSource();
      noise.buffer = buffer;
      const noiseGain = ctx.createGain();
      noiseGain.gain.setValueAtTime(0.1, now + 0.11);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
      noise.connect(noiseGain);
      noiseGain.connect(ctx.destination);
      noise.start(now + 0.11);
    } catch (err) {
      console.warn('Audio play release error:', err);
    }
  }

  /**
   * Play Busy Channel Error Tone
   */
  public playBusySound() {
    if (!this.soundEnabled) return;
    try {
      const ctx = this.getContext();
      const now = ctx.currentTime;

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(320, now);
      osc.frequency.setValueAtTime(280, now + 0.08);

      gain.gain.setValueAtTime(0.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.2);
    } catch (err) {
      console.warn('Audio busy play error:', err);
    }
  }

  /**
   * Trigger Haptic Feedback matching Flutter specification:
   * - Light impact on press: HapticFeedback.lightImpact()
   * - Double impact on release
   */
  public triggerHapticPress() {
    if ('vibrate' in navigator) {
      try {
        navigator.vibrate(30); // Light impact
      } catch (e) {
        // Ignore iframe vibration restrictions if any
      }
    }
  }

  public triggerHapticRelease() {
    if ('vibrate' in navigator) {
      try {
        navigator.vibrate([25, 40, 25]); // Double impact on release
      } catch (e) {
        // Ignore iframe vibration restrictions if any
      }
    }
  }

  /**
   * Start microphone audio analyzer stream for live PTT visual feedback
   */
  public async startMicCapture(): Promise<{ success: boolean; error?: string }> {
    try {
      const ctx = this.getContext();
      this.micStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });

      this.analyser = ctx.createAnalyser();
      this.analyser.fftSize = 64;
      this.analyser.smoothingTimeConstant = 0.5;

      this.micSource = ctx.createMediaStreamSource(this.micStream);
      this.micSource.connect(this.analyser);
      this.isMicActive = true;

      return { success: true };
    } catch (err: any) {
      console.warn('Mic access warning:', err);
      this.isMicActive = false;
      return {
        success: false,
        error: err?.message || 'Acceso al micrófono denegado o no disponible en este navegador.',
      };
    }
  }

  /**
   * Stop mic stream and analyzer
   */
  public stopMicCapture() {
    if (this.micStream) {
      this.micStream.getTracks().forEach((track) => track.stop());
      this.micStream = null;
    }
    if (this.micSource) {
      this.micSource.disconnect();
      this.micSource = null;
    }
    this.analyser = null;
    this.isMicActive = false;
  }

  /**
   * Get current volume level (0 to 100)
   */
  public getAudioLevel(): number {
    if (!this.analyser || !this.isMicActive) return 0;
    const dataArray = new Uint8Array(this.analyser.frequencyBinCount);
    this.analyser.getByteFrequencyData(dataArray);

    let sum = 0;
    for (let i = 0; i < dataArray.length; i++) {
      sum += dataArray[i];
    }
    const average = sum / dataArray.length;
    return Math.min(100, Math.round((average / 128) * 100));
  }

  /**
   * Playback audio recording transcription using Web Speech API with radio squelch effects
   */
  public playRecordingWithRadioEffect(text: string, onEnded?: () => void) {
    if (!this.soundEnabled) {
      if (onEnded) onEnded();
      return;
    }

    this.playPttPressSound();

    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'es-AR';
      utterance.rate = 1.05;
      utterance.pitch = 0.95;

      utterance.onend = () => {
        this.playPttReleaseSound();
        if (onEnded) onEnded();
      };

      utterance.onerror = () => {
        this.playPttReleaseSound();
        if (onEnded) onEnded();
      };

      setTimeout(() => {
        window.speechSynthesis.speak(utterance);
      }, 100);
    } else {
      setTimeout(() => {
        this.playPttReleaseSound();
        if (onEnded) onEnded();
      }, 2000);
    }
  }

  public stopPlayback() {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
  }
}

export const audioEngine = new AudioEngine();

