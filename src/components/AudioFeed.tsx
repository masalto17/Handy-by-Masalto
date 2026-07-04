import React, { useState, useEffect } from 'react';
import { 
  Play, 
  Square, 
  Mic, 
  Clock, 
  Volume2, 
  Search, 
  Copy, 
  Check, 
  CheckCheck,
  AlertTriangle, 
  Radio, 
  Filter, 
  User, 
  Sparkles,
  Trash2,
  Send
} from 'lucide-react';
import { AudioRecording, UserRole, DeliveryStatus } from '../types';
import { audioEngine } from '../services/audioEngine';

interface AudioFeedProps {
  recordings: AudioRecording[];
  activeChannelCode: string;
  onClearRecordings?: () => void;
  onAddSampleRecording?: () => void;
}

export const AudioFeed: React.FC<AudioFeedProps> = ({
  recordings,
  activeChannelCode,
  onClearRecordings,
  onAddSampleRecording
}) => {
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [filterChannel, setFilterChannel] = useState<'ACTIVE' | 'ALL'>('ACTIVE');
  const [searchTerm, setSearchTerm] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Stop playback on unmount
  useEffect(() => {
    return () => {
      audioEngine.stopPlayback();
    };
  }, []);

  const handlePlayPause = (rec: AudioRecording) => {
    if (playingId === rec.id) {
      audioEngine.stopPlayback();
      setPlayingId(null);
    } else {
      audioEngine.stopPlayback();
      setPlayingId(rec.id);
      audioEngine.playRecordingWithRadioEffect(rec.transcription, () => {
        setPlayingId(null);
      });
    }
  };

  const handleCopyText = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const formatDuration = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const formatTime = (ts: string) => {
    try {
      const date = new Date(ts);
      if (isNaN(date.getTime())) return ts;
      return date.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    } catch {
      return ts;
    }
  };

  const getRoleBadgeStyle = (role: UserRole | string) => {
    switch (role) {
      case 'Seguridad':
        return 'bg-amber-500/15 text-amber-400 border-amber-500/30';
      case 'Producción':
        return 'bg-red-500/15 text-red-400 border-red-500/30';
      case 'Médico':
        return 'bg-rose-500/15 text-rose-400 border-rose-500/30';
      case 'Logística':
        return 'bg-sky-500/15 text-sky-400 border-sky-500/30';
      case 'Escenario':
        return 'bg-purple-500/15 text-purple-400 border-purple-500/30';
      default:
        return 'bg-zinc-800 text-zinc-300 border-zinc-700';
    }
  };

  const renderDeliveryBadge = (status?: DeliveryStatus) => {
    const currentStatus: DeliveryStatus = status || 'delivered';

    switch (currentStatus) {
      case 'sending':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] bg-amber-500/20 text-amber-400 px-1.5 py-0.5 rounded border border-amber-500/30 font-mono font-bold animate-pulse" title="Enviando al servidor...">
            <Clock className="w-3 h-3 text-amber-400 animate-spin" />
            <span>Enviando...</span>
          </span>
        );
      case 'sent':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] bg-sky-500/20 text-sky-400 px-1.5 py-0.5 rounded border border-sky-500/30 font-mono font-bold" title="Enviado al nodo local">
            <Check className="w-3 h-3 text-sky-400" />
            <span>Enviado</span>
          </span>
        );
      case 'delivered':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] bg-emerald-500/20 text-emerald-400 px-1.5 py-0.5 rounded border border-emerald-500/30 font-mono font-bold" title="Entregado y confirmado por los servidores y operadores">
            <CheckCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span>Entregado</span>
          </span>
        );
      case 'failed':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] bg-rose-500/20 text-rose-400 px-1.5 py-0.5 rounded border border-rose-500/30 font-mono font-bold" title="Fallo de red - En cola de reintento IndexedDB">
            <AlertTriangle className="w-3 h-3 text-rose-400" />
            <span>En Cola Offline</span>
          </span>
        );
      default:
        return null;
    }
  };

  const filteredRecordings = recordings.filter((rec) => {
    if (filterChannel === 'ACTIVE' && rec.channel_code !== activeChannelCode) {
      return false;
    }
    if (searchTerm.trim() !== '') {
      const term = searchTerm.toLowerCase();
      const matchName = rec.sender_name.toLowerCase().includes(term);
      const matchRole = rec.sender_role.toLowerCase().includes(term);
      const matchText = rec.transcription.toLowerCase().includes(term);
      const matchCh = rec.channel_code.toLowerCase().includes(term);
      return matchName || matchRole || matchText || matchCh;
    }
    return true;
  });

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl flex flex-col overflow-hidden shadow-xl font-sans">
      
      {/* Header Bar */}
      <div className="p-4 border-b border-zinc-800 bg-zinc-950/80 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <div className="p-2 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
            <Radio className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <h3 className="text-sm sm:text-base font-bold text-white flex items-center gap-2">
              Audio Feed <span className="text-[10px] bg-red-500/20 text-red-400 font-mono px-2 py-0.5 rounded border border-red-500/30">Transmisiones</span>
            </h3>
            <p className="text-xs text-zinc-400">Últimas órdenes de voz y grabaciones del canal</p>
          </div>
        </div>

        {/* Filter Toggle Buttons */}
        <div className="flex items-center gap-1.5 bg-zinc-900 p-1 rounded-xl border border-zinc-800 text-xs font-medium">
          <button
            onClick={() => setFilterChannel('ACTIVE')}
            className={`px-3 py-1.5 rounded-lg transition cursor-pointer ${
              filterChannel === 'ACTIVE'
                ? 'bg-red-500 text-zinc-950 font-bold shadow'
                : 'text-zinc-400 hover:text-white'
            }`}
          >
            Canal {activeChannelCode}
          </button>
          <button
            onClick={() => setFilterChannel('ALL')}
            className={`px-3 py-1.5 rounded-lg transition cursor-pointer ${
              filterChannel === 'ALL'
                ? 'bg-red-500 text-zinc-950 font-bold shadow'
                : 'text-zinc-400 hover:text-white'
            }`}
          >
            Todos ({recordings.length})
          </button>
        </div>
      </div>

      {/* Search & Actions Bar */}
      <div className="px-4 py-2.5 bg-zinc-950/40 border-b border-zinc-800/80 flex flex-wrap items-center justify-between gap-2">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-3.5 h-3.5 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Buscar por emisor, rol o transcripción..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-8 pr-3 py-1.5 bg-zinc-900 border border-zinc-800 focus:border-red-400 rounded-lg text-xs text-white focus:outline-none placeholder:text-zinc-500"
          />
        </div>

        <div className="flex items-center gap-2">
          {onAddSampleRecording && (
            <button
              onClick={onAddSampleRecording}
              className="px-2.5 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-red-400 text-xs rounded-lg border border-zinc-700 transition flex items-center gap-1 cursor-pointer font-medium"
              title="Simular audio en canal"
            >
              <Sparkles className="w-3.5 h-3.5" /> + Simular Audio
            </button>
          )}
          {onClearRecordings && recordings.length > 0 && (
            <button
              onClick={onClearRecordings}
              className="p-1.5 text-zinc-400 hover:text-rose-400 bg-zinc-900 hover:bg-zinc-800 rounded-lg text-xs border border-zinc-800 transition cursor-pointer"
              title="Limpiar feed"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Feed List Container */}
      <div className="p-3 sm:p-4 overflow-y-auto max-h-[420px] space-y-3">
        {filteredRecordings.length === 0 ? (
          <div className="text-center py-10 px-4 text-zinc-500 space-y-2">
            <Mic className="w-8 h-8 text-zinc-600 mx-auto opacity-50" />
            <p className="text-xs font-medium">No se registraron transmisiones en este canal.</p>
            <p className="text-[11px] text-zinc-600">Mantenga presionado el botón PTT para emitir un comunicado de voz.</p>
          </div>
        ) : (
          filteredRecordings.map((rec) => {
            const isPlaying = playingId === rec.id;

            return (
              <div
                key={rec.id}
                className={`p-3.5 rounded-xl border transition-all ${
                  rec.is_emergency
                    ? 'bg-rose-950/20 border-rose-500/40 shadow-rose-950/20'
                    : 'bg-zinc-950/60 border-zinc-800/80 hover:border-zinc-700'
                }`}
              >
                {/* Top Line: Emisor, Rol Badge, Channel, Timestamp */}
                <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center text-red-400 font-bold text-xs shrink-0">
                      {rec.sender_name.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold text-white tracking-tight">
                          {rec.sender_name}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded border font-semibold ${getRoleBadgeStyle(rec.sender_role)}`}>
                          {rec.sender_role}
                        </span>
                        {rec.is_emergency && (
                          <span className="text-[10px] bg-rose-500/20 text-rose-400 border border-rose-500/40 font-bold px-1.5 py-0.5 rounded flex items-center gap-1 animate-pulse">
                            <AlertTriangle className="w-3 h-3" /> SOS
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 font-mono text-[11px] text-zinc-400">
                    {renderDeliveryBadge(rec.delivery_status)}
                    <span className="bg-zinc-900 border border-zinc-800 text-red-400 font-bold px-1.5 py-0.5 rounded">
                      {rec.channel_code}
                    </span>
                    <span className="flex items-center gap-1 text-zinc-400">
                      <Clock className="w-3 h-3" /> {formatTime(rec.timestamp)}
                    </span>
                  </div>
                </div>

                {/* Transcription Text Box */}
                <div className="bg-zinc-900/90 border border-zinc-800/80 rounded-lg p-2.5 my-2 text-xs text-zinc-200 font-sans leading-relaxed relative group">
                  <p className="italic text-zinc-300">
                    "{rec.transcription}"
                  </p>
                  <button
                    onClick={() => handleCopyText(rec.id, rec.transcription)}
                    className="absolute top-2 right-2 p-1 text-zinc-500 hover:text-zinc-200 opacity-0 group-hover:opacity-100 transition rounded hover:bg-zinc-800"
                    title="Copiar transcripción"
                  >
                    {copiedId === rec.id ? <Check className="w-3.5 h-3.5 text-red-400" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>

                {/* Bottom Player Controls & Audio Duration Waveform */}
                <div className="flex items-center justify-between gap-3 pt-1">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handlePlayPause(rec)}
                      className={`p-2 rounded-xl border transition flex items-center justify-center cursor-pointer ${
                        isPlaying
                          ? 'bg-rose-500 text-white border-rose-400 animate-pulse'
                          : 'bg-red-500 hover:bg-red-400 text-zinc-950 font-bold border-red-400'
                      }`}
                      title={isPlaying ? 'Detener audio' : 'Reproducir audio'}
                    >
                      {isPlaying ? <Square className="w-3.5 h-3.5 fill-current" /> : <Play className="w-3.5 h-3.5 fill-current ml-0.5" />}
                    </button>

                    <div className="flex items-center gap-1.5 text-xs font-mono font-medium text-zinc-300">
                      <Volume2 className={`w-3.5 h-3.5 ${isPlaying ? 'text-red-400 animate-bounce' : 'text-zinc-500'}`} />
                      <span>{formatDuration(rec.duration_seconds)}</span>
                    </div>
                  </div>

                  {/* Animated Waveform Visualizer for Audio Clip */}
                  <div className="flex items-center gap-0.5 h-4 flex-1 max-w-[120px] justify-end opacity-80">
                    {[40, 70, 30, 90, 50, 80, 40, 100, 60, 30].map((height, idx) => (
                      <span
                        key={idx}
                        className={`w-1 rounded-full transition-all duration-300 ${
                          isPlaying
                            ? 'bg-red-400 animate-pulse'
                            : 'bg-zinc-700'
                        }`}
                        style={{
                          height: isPlaying ? `${Math.max(20, (height * (idx % 3 + 1)) % 100)}%` : `${height * 0.4}%`,
                          animationDelay: `${idx * 0.08}s`
                        }}
                      />
                    ))}
                  </div>
                </div>

              </div>
            );
          })
        )}
      </div>

    </div>
  );
};
