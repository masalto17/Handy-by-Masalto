import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Radio, 
  Volume2, 
  VolumeX, 
  Mic, 
  MicOff, 
  Activity, 
  Database, 
  LogOut, 
  Lock, 
  Wifi, 
  ChevronRight, 
  ChevronLeft,
  Users,
  ShieldCheck,
  AlertTriangle,
  MoveHorizontal,
  Hand,
  Headphones,
  X,
  FileText,
  BarChart2,
  Bell,
  BellRing
} from 'lucide-react';
import { EventDetails, RadioChannel, UserRole, PttStatus, AudioRecording } from '../types';
import { LogServicio } from '../services/logService';
import { audioEngine } from '../services/audioEngine';
import { indexedDbService } from '../services/indexedDbService';
import { notificationService } from '../services/notificationService';
import { AudioFeed } from './AudioFeed';
import { LoggingProposalModal } from './LoggingProposalModal';
import { ChannelAnalyticsModal } from './ChannelAnalyticsModal';

interface HandyViewProps {
  event: EventDetails;
  userName: string;
  userRole: UserRole;
  onLogout: () => void;
  onOpenSqlModal: () => void;
  onOpenLogsModal: () => void;
  isSimulatedBusy: boolean;
}

const DEFAULT_RECORDINGS: AudioRecording[] = [
  {
    id: 'rec-1',
    event_id: 'event-01',
    channel_code: 'CH-01',
    channel_name: 'PRODUCCIÓN GENERAL',
    sender_name: 'Laura Pérez',
    sender_role: 'Producción',
    timestamp: new Date(Date.now() - 1000 * 60 * 3).toISOString(),
    duration_seconds: 6,
    transcription: 'Atención Producción general, habilitado ingreso VIP por acceso norte. Todo en orden.',
  },
  {
    id: 'rec-2',
    event_id: 'event-01',
    channel_code: 'CH-01',
    channel_name: 'PRODUCCIÓN GENERAL',
    sender_name: 'Carlos M.',
    sender_role: 'Coordinación VIP',
    timestamp: new Date(Date.now() - 1000 * 60 * 7).toISOString(),
    duration_seconds: 4,
    transcription: 'Copia Producción. Artistas principales en camarines, prueba de sonido finalizada.',
  },
  {
    id: 'rec-3',
    event_id: 'event-01',
    channel_code: 'CH-02',
    channel_name: 'SEGURIDAD & ACCESOS',
    sender_name: 'Martín González',
    sender_role: 'Seguridad',
    timestamp: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
    duration_seconds: 8,
    transcription: 'Puesto de control 1 reporta vallado perimetral reforzado sin novedad.',
  },
  {
    id: 'rec-4',
    event_id: 'event-01',
    channel_code: 'CH-04',
    channel_name: 'EMERGENCIAS & MÉDICO',
    sender_name: 'Dra. Sofía Ramos',
    sender_role: 'Médico',
    timestamp: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
    duration_seconds: 5,
    transcription: 'Unidad de primeros auxilios lista. Equipos con frecuencia limpia 5/5.',
  }
];

const CHANNELS: RadioChannel[] = [
  {
    id: 'CH-01',
    code: 'CH-01',
    name: 'PRODUCCIÓN GENERAL',
    frequency: '462.550 MHz',
    description: 'Coordinación central y programa principal',
    active_users_count: 12,
    color: 'red',
  },
  {
    id: 'CH-02',
    code: 'CH-02',
    name: 'SEGURIDAD & ACCESOS',
    frequency: '462.575 MHz',
    description: 'Control de puertas, VIP y perímetro',
    active_users_count: 8,
    color: 'amber',
  },
  {
    id: 'CH-03',
    code: 'CH-03',
    name: 'LOGÍSTICA & MONTAJE',
    frequency: '462.600 MHz',
    description: 'Escenario, carga y abastecimiento',
    active_users_count: 6,
    color: 'sky',
  },
  {
    id: 'CH-04',
    code: 'CH-04',
    name: 'EMERGENCIAS & MÉDICO',
    frequency: '462.625 MHz',
    description: 'Puestos de primeros auxilios y evacuación',
    active_users_count: 4,
    color: 'rose',
  },
];

export const HandyView: React.FC<HandyViewProps> = ({
  event,
  userName,
  userRole,
  onLogout,
  onOpenSqlModal,
  onOpenLogsModal,
  isSimulatedBusy,
}) => {
  const [currentChannelIndex, setCurrentChannelIndex] = useState(0);
  const currentChannel = CHANNELS[currentChannelIndex];

  const [pttState, setPttState] = useState<PttStatus>('idle');
  const [isPressing, setIsPressing] = useState(false);
  const [soundFxEnabled, setSoundFxEnabled] = useState(true);
  const [micAudioLevel, setMicAudioLevel] = useState(0);
  const [activeSpeaker, setActiveSpeaker] = useState<{ name: string; role: string } | null>(null);

  const [recordings, setRecordings] = useState<AudioRecording[]>(DEFAULT_RECORDINGS);
  const [isAudioFeedOpen, setIsAudioFeedOpen] = useState(false);
  const [isLoggingProposalOpen, setIsLoggingProposalOpen] = useState(false);
  const [isAnalyticsOpen, setIsAnalyticsOpen] = useState(false);
  const [hasPushPermission, setHasPushPermission] = useState<boolean>(false);

  useEffect(() => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      setHasPushPermission(Notification.permission === 'granted');
    }
  }, []);

  const handleRequestPush = async () => {
    const perm = await notificationService.requestPermission();
    setHasPushPermission(perm === 'granted');
  };

  const [slideDirection, setSlideDirection] = useState<'left' | 'right'>('right');
  const touchStartXRef = useRef<number | null>(null);
  const touchStartYRef = useRef<number | null>(null);

  const pressStartTimeRef = useRef<number | null>(null);
  const animFrameRef = useRef<number | null>(null);

  // Sync PTT state with external simulator busy state
  useEffect(() => {
    if (isSimulatedBusy) {
      setPttState('busy');
      setActiveSpeaker({ name: 'Martín G.', role: 'Seguridad' });
    } else if (pttState === 'busy') {
      setPttState('idle');
      setActiveSpeaker(null);
    }
  }, [isSimulatedBusy]);

  // Audio level polling while talking
  useEffect(() => {
    if (pttState === 'talking') {
      const updateLevel = () => {
        const level = audioEngine.getAudioLevel();
        setMicAudioLevel(level > 0 ? level : Math.floor(30 + Math.random() * 50));
        animFrameRef.current = requestAnimationFrame(updateLevel);
      };
      updateLevel();
    } else {
      setMicAudioLevel(0);
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    }

    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, [pttState]);

  // Channel switch handler
  const handleSelectChannel = (newIndex: number, direction?: 'left' | 'right') => {
    if (newIndex < 0 || newIndex >= CHANNELS.length) return;
    if (newIndex === currentChannelIndex) return;

    const dir = direction || (newIndex > currentChannelIndex ? 'right' : 'left');
    setSlideDirection(dir);

    const oldCh = CHANNELS[currentChannelIndex].code;
    const newCh = CHANNELS[newIndex].code;

    setCurrentChannelIndex(newIndex);
    LogServicio.logChannelChange(oldCh, newCh);

    if (soundFxEnabled) {
      audioEngine.playPttPressSound();
    }
  };

  // Touch handlers for swipe gesture
  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartXRef.current = e.touches[0].clientX;
    touchStartYRef.current = e.touches[0].clientY;
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (touchStartXRef.current === null || touchStartYRef.current === null) return;
    const diffX = e.changedTouches[0].clientX - touchStartXRef.current;
    const diffY = e.changedTouches[0].clientY - touchStartYRef.current;

    if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 40) {
      if (diffX < 0) {
        handleSelectChannel(currentChannelIndex + 1, 'right');
      } else {
        handleSelectChannel(currentChannelIndex - 1, 'left');
      }
    }

    touchStartXRef.current = null;
    touchStartYRef.current = null;
  };

  // PTT Press Start
  const handlePttStart = async (e?: React.SyntheticEvent) => {
    if (e) e.preventDefault();
    if (pttState === 'busy' || isPressing) {
      audioEngine.playBusySound();
      return;
    }

    setIsPressing(true);
    setPttState('talking');
    pressStartTimeRef.current = Date.now();

    // Haptic feedback & sound FX as specified
    audioEngine.triggerHapticPress(); // HapticFeedback.lightImpact()
    audioEngine.playPttPressSound();

    LogServicio.logPttStart();

    // Try microphone capture
    await audioEngine.startMicCapture();
  };

  // PTT Press End / Release
  const handlePttEnd = (e?: React.SyntheticEvent) => {
    if (e) e.preventDefault();
    if (!isPressing && pttState !== 'talking') return;

    setIsPressing(false);
    setPttState('idle');

    // Haptic double impact on release as specified
    audioEngine.triggerHapticRelease();
    audioEngine.playPttReleaseSound(); // Roger beep over-and-out

    audioEngine.stopMicCapture();

    if (pressStartTimeRef.current) {
      const durationMs = Date.now() - pressStartTimeRef.current;
      const durationSecs = Math.max(1, Math.round(durationMs / 1000));
      LogServicio.logPttEnd(durationMs);

      const sampleTexts = [
        `Orden de voz de ${userName} (${userRole}): Copia 5/5 en ${currentChannel.code}.`,
        `Reporte operativo en canal ${currentChannel.code}: sin novedades en sector.`,
        `Coordinación desde ${userRole}: confirmando recepción limpia en ${currentChannel.code}.`,
        `Frecuencia ${currentChannel.frequency} activa y sin interferencias.`
      ];
      const text = sampleTexts[Math.floor(Math.random() * sampleTexts.length)];

      const newRec: AudioRecording = {
        id: `rec-${Date.now()}`,
        event_id: event.id,
        channel_code: currentChannel.code,
        channel_name: currentChannel.name,
        sender_name: userName,
        sender_role: userRole,
        timestamp: new Date().toISOString(),
        duration_seconds: durationSecs,
        transcription: text,
        delivery_status: 'sending',
        delivery_timestamp: new Date().toISOString(),
      };

      setRecordings((prev) => [newRec, ...prev]);
      indexedDbService.saveRecording(newRec);

      // Simulate remote server delivery confirmation after 1.2s
      setTimeout(() => {
        setRecordings((prev) =>
          prev.map((item) =>
            item.id === newRec.id
              ? { ...item, delivery_status: 'delivered', delivery_timestamp: new Date().toISOString() }
              : item
          )
        );
        indexedDbService.updateRecordingDeliveryStatus(newRec.id, 'delivered');
      }, 1200);

      // Push notification trigger if app in background
      notificationService.notifyVoiceMessage(userName, userRole, currentChannel.code, text);

      pressStartTimeRef.current = null;
    }
  };

  const handleAddSampleRecording = () => {
    const sampleAgents = [
      { name: 'Gabriel T.', role: 'Producción', text: 'Acreditaciones liberadas. Flujo de ingreso constante.' },
      { name: 'Esteban R.', role: 'Seguridad', text: 'Atención control, vallado perimetral supervisado sin novedades.' },
      { name: 'Valeria S.', role: 'Logística', text: 'Abastecimiento de barras completado en sector VIP.' },
      { name: 'Dr. Hugo M.', role: 'Médico', text: 'Unidad de emergencias en posición 1 lista para actuar.' },
    ];
    const item = sampleAgents[Math.floor(Math.random() * sampleAgents.length)];
    const recId = `rec-${Date.now()}`;
    const newRec: AudioRecording = {
      id: recId,
      event_id: event.id,
      channel_code: currentChannel.code,
      channel_name: currentChannel.name,
      sender_name: item.name,
      sender_role: item.role,
      timestamp: new Date().toISOString(),
      duration_seconds: Math.floor(Math.random() * 5) + 3,
      transcription: item.text,
      delivery_status: 'sending',
      delivery_timestamp: new Date().toISOString(),
    };
    setRecordings((prev) => [newRec, ...prev]);
    indexedDbService.saveRecording(newRec);

    setTimeout(() => {
      setRecordings((prev) =>
        prev.map((r) =>
          r.id === recId
            ? { ...r, delivery_status: 'delivered', delivery_timestamp: new Date().toISOString() }
            : r
        )
      );
      indexedDbService.updateRecordingDeliveryStatus(recId, 'delivered');
    }, 1000);

    notificationService.notifyVoiceMessage(item.name, item.role, currentChannel.code, item.text);
  };

  const toggleSoundFx = () => {
    const next = !soundFxEnabled;
    setSoundFxEnabled(next);
    audioEngine.setSoundEnabled(next);
  };


  // Determine Background Color based on state:
  // - "Rojo brillante cuando cambie el estado a 'hablando'"
  // - "Rojo oscuro si está 'ocupado'"
  // - Neutral dark zinc when idle
  let bgClass = 'bg-zinc-950 text-zinc-100'; // idle
  if (pttState === 'talking') {
    bgClass = 'bg-red-600 text-white shadow-2xl transition-colors duration-200'; // ROJO BRILLANTE
  } else if (pttState === 'busy') {
    bgClass = 'bg-rose-950 text-white shadow-2xl transition-colors duration-200'; // ROJO OSCURO
  }

  return (
    <div className={`min-h-screen ${bgClass} transition-colors duration-300 flex flex-col justify-between p-2 sm:p-5 select-none relative overflow-x-hidden font-sans`}>
      
      {/* Top Header Navigation Bar */}
      <header className="flex justify-between items-center max-w-lg mx-auto w-full z-20 bg-zinc-950/90 backdrop-blur-md px-3.5 py-2.5 rounded-2xl border border-zinc-800/80 shadow-2xl">
        <div className="flex items-center gap-2.5">
          <div className="w-2.5 h-2.5 rounded-full bg-red-500 shadow-[0_0_10px_#ef4444] animate-pulse shrink-0" />
          <div className="min-w-0">
            <h1 className="text-xs font-black font-mono tracking-wider uppercase text-zinc-100 truncate max-w-[130px] sm:max-w-[200px]">
              {event.name}
            </h1>
            <p className="text-[10px] text-zinc-400 font-medium truncate">
              {userName} • <span className="font-bold text-red-400 uppercase">{userRole}</span>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1 sm:gap-1.5 shrink-0">
          {/* Channel Analytics Heatmap Button */}
          <button
            onClick={() => setIsAnalyticsOpen(true)}
            id="btn-open-analytics-handy"
            className="p-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-xl transition text-xs flex items-center gap-1 font-mono font-bold cursor-pointer"
            title="Mapa de Calor & Métricas de Canal"
          >
            <BarChart2 className="w-4 h-4 text-red-400" />
            <span className="hidden sm:inline text-xs">Métricas</span>
          </button>

          {/* Push Notifications Toggle */}
          <button
            onClick={handleRequestPush}
            className={`p-2 border rounded-xl transition text-xs cursor-pointer ${
              hasPushPermission
                ? 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
                : 'bg-zinc-900 hover:bg-zinc-800 text-zinc-400 border-zinc-800'
            }`}
            title={hasPushPermission ? 'Notificaciones Push Activas' : 'Activar Notificaciones Push'}
          >
            {hasPushPermission ? <BellRing className="w-4 h-4 text-emerald-400" /> : <Bell className="w-4 h-4" />}
          </button>

          {/* Audio Feed Button */}
          <button
            onClick={() => setIsAudioFeedOpen(true)}
            id="btn-open-audio-feed"
            className="p-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-xl transition text-xs flex items-center gap-1 font-mono font-bold cursor-pointer"
            title="Ver Audio Feed & Grabaciones"
          >
            <Headphones className="w-4 h-4 text-red-400" />
            <span className="hidden sm:inline text-xs">Feed</span>
            <span className="bg-red-500 text-zinc-950 px-1.5 py-0.2 rounded-full text-[10px] font-extrabold ml-0.5">
              {recordings.filter(r => r.channel_code === currentChannel.code).length}
            </span>
          </button>

          {/* Sound FX Toggle */}
          <button
            onClick={toggleSoundFx}
            className="p-2 bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 rounded-xl text-zinc-200 transition text-xs cursor-pointer"
            title={soundFxEnabled ? 'Sonido FX activado' : 'Sonido FX silenciado'}
          >
            {soundFxEnabled ? <Volume2 className="w-4 h-4 text-red-400" /> : <VolumeX className="w-4 h-4 text-rose-400" />}
          </button>

          {/* Proposal Modal Button */}
          <button
            onClick={() => setIsLoggingProposalOpen(true)}
            id="btn-open-proposal-handy"
            className="p-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-xl transition text-xs flex items-center gap-1 font-mono font-bold cursor-pointer"
            title="Ver Propuesta de Logging MasAlto"
          >
            <FileText className="w-4 h-4 text-red-400" />
            <span className="hidden md:inline text-[10px]">Propuesta</span>
          </button>

          {/* Logs Modal Button */}
          <button
            onClick={onOpenLogsModal}
            id="btn-open-logs-handy"
            className="p-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-xl transition text-xs flex items-center gap-1 font-mono font-bold cursor-pointer"
            title="Ver Logs Operativos"
          >
            <Activity className="w-4 h-4 text-red-400" />
          </button>

          {/* SQL Migration Modal */}
          <button
            onClick={onOpenSqlModal}
            className="p-2 bg-zinc-900 hover:bg-zinc-800 text-zinc-200 border border-zinc-800 rounded-xl transition text-xs cursor-pointer"
            title="Ver Esquema SQL & RLS"
          >
            <Database className="w-4 h-4" />
          </button>

          {/* Exit / Logout */}
          <button
            onClick={onLogout}
            className="p-2 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/20 rounded-xl transition text-xs cursor-pointer"
            title="Cambiar Operador"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* Main Physical HANDY Radio Body Frame */}
      <main className="max-w-lg mx-auto w-full my-auto flex flex-col justify-between items-center gap-2 py-2 z-10 flex-1 relative">
        
        {/* Top Hardware Device Accent: Antenna & Rotary Dial Knob */}
        <div className="w-full flex justify-between items-end px-6 -mb-2 z-0 opacity-90">
          {/* Left Antenna */}
          <div className="flex flex-col items-center">
            <div className="w-2.5 h-6 bg-gradient-to-b from-zinc-700 to-zinc-900 rounded-t-sm border-t border-zinc-600 shadow-md" />
            <div className="w-4 h-3 bg-zinc-800 rounded-t-md border-x border-t border-zinc-700" />
          </div>

          {/* Brand Mark */}
          <div className="text-[10px] font-mono font-bold uppercase tracking-widest text-red-400/80 bg-zinc-950/80 px-2 py-0.5 rounded border border-zinc-800">
            HANDY • MASALTO PTT-400
          </div>

          {/* Right Rotary Dial */}
          <div className="flex flex-col items-center">
            <div className="w-6 h-5 bg-gradient-to-r from-zinc-800 via-zinc-700 to-zinc-900 rounded-t-lg border-t border-x border-zinc-600 flex items-center justify-center space-x-0.5">
              <div className="w-0.5 h-3 bg-zinc-950" />
              <div className="w-0.5 h-3 bg-zinc-950" />
              <div className="w-0.5 h-3 bg-zinc-950" />
            </div>
          </div>
        </div>

        {/* OLED Radio Display & Channel Swipe Panel */}
        <motion.div
          drag="x"
          dragConstraints={{ left: 0, right: 0 }}
          dragElastic={0.2}
          onDragEnd={(_e, info) => {
            if (info.offset.x < -40 || info.velocity.x < -200) {
              handleSelectChannel(currentChannelIndex + 1, 'right');
            } else if (info.offset.x > 40 || info.velocity.x > 200) {
              handleSelectChannel(currentChannelIndex - 1, 'left');
            }
          }}
          onTouchStart={handleTouchStart}
          onTouchEnd={handleTouchEnd}
          id="lcd-channel-swipe-panel"
          className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-2xl p-4 shadow-2xl backdrop-blur-md relative overflow-hidden cursor-grab active:cursor-grabbing touch-pan-y select-none group"
        >
          {/* Top Status Bar in OLED Display */}
          <div className="flex justify-between items-center border-b border-zinc-800/80 pb-2 mb-2 text-xs font-mono">
            <div className="flex items-center gap-1.5">
              <Wifi className="w-3.5 h-3.5 text-red-400" />
              <span className="text-zinc-300">FREC: <strong className="text-red-400 font-bold">{currentChannel.frequency}</strong></span>
            </div>

            <div className="flex items-center gap-1 text-[10px] text-red-400 bg-red-500/10 px-2 py-0.5 rounded border border-red-500/20 font-bold tracking-wider">
              <MoveHorizontal className="w-3 h-3 animate-pulse text-red-400" />
              <span>SWIPE ◄ ►</span>
            </div>

            <div className="flex items-center gap-1.5">
              <Users className="w-3.5 h-3.5 text-zinc-400" />
              <span className="text-zinc-300 text-[11px] font-bold">{currentChannel.active_users_count} ONLINE</span>
            </div>
          </div>

          {/* Channel Display & Switch Controls */}
          <div className="flex items-center justify-between gap-2 relative min-h-[64px]">
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleSelectChannel(currentChannelIndex - 1, 'left');
              }}
              disabled={currentChannelIndex === 0}
              id="btn-prev-channel"
              className="p-2.5 bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 disabled:opacity-30 rounded-xl text-zinc-200 transition cursor-pointer z-10"
              title="Canal anterior"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>

            <AnimatePresence mode="wait" custom={slideDirection}>
              <motion.div
                key={currentChannel.code}
                initial={{ x: slideDirection === 'right' ? 50 : -50, opacity: 0 }}
                animate={{ x: 0, opacity: 1 }}
                exit={{ x: slideDirection === 'right' ? -50 : 50, opacity: 0 }}
                transition={{ duration: 0.16, ease: 'easeOut' }}
                className="text-center flex-1 px-2 pointer-events-none"
              >
                <span className="text-[10px] font-mono tracking-widest text-red-400 font-bold uppercase block">
                  CANAL ACTIVO ({currentChannelIndex + 1}/{CHANNELS.length})
                </span>
                <h2 className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-white drop-shadow">
                  {currentChannel.code}
                </h2>
                <p className="text-xs font-bold text-zinc-300 uppercase tracking-widest truncate">
                  {currentChannel.name}
                </p>
              </motion.div>
            </AnimatePresence>

            <button
              onClick={(e) => {
                e.stopPropagation();
                handleSelectChannel(currentChannelIndex + 1, 'right');
              }}
              disabled={currentChannelIndex === CHANNELS.length - 1}
              id="btn-next-channel"
              className="p-2.5 bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 disabled:opacity-30 rounded-xl text-zinc-200 transition cursor-pointer z-10"
              title="Siguiente canal"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>

          {/* Pagination Page Dots */}
          <div className="flex items-center justify-center gap-1.5 my-2">
            {CHANNELS.map((ch, idx) => (
              <button
                key={ch.id}
                onClick={(e) => {
                  e.stopPropagation();
                  handleSelectChannel(idx);
                }}
                className={`h-1.5 rounded-full transition-all duration-300 cursor-pointer ${
                  idx === currentChannelIndex
                    ? 'w-6 bg-red-500 shadow-[0_0_8px_#ef4444]'
                    : 'w-1.5 bg-zinc-800 hover:bg-zinc-700'
                }`}
                title={`Cambiar a ${ch.code}: ${ch.name}`}
              />
            ))}
          </div>

          {/* Real-time Transmission Status / VU Meter Audio Equalizer */}
          <div className="mt-2 pt-2 border-t border-zinc-800/80">
            {pttState === 'talking' && (
              <div className="space-y-1.5 text-center">
                <span className="text-xs font-mono font-bold uppercase tracking-widest text-red-300 flex items-center justify-center gap-1.5 animate-pulse">
                  <Mic className="w-4 h-4 text-red-400" /> TRANSMITIENDO EN VIVO...
                </span>
                
                {/* Visual Audio Waveform Spectrum */}
                <div className="flex items-center justify-center gap-1 h-8 px-4">
                  {[...Array(14)].map((_, i) => {
                    const heightPct = Math.min(100, Math.max(15, (micAudioLevel * (i % 2 === 0 ? 1.3 : 0.7))));
                    return (
                      <div
                        key={i}
                        className="w-1.5 sm:w-2 bg-red-400 rounded-full transition-all duration-75 shadow-[0_0_6px_#ef4444]"
                        style={{ height: `${heightPct}%` }}
                      />
                    );
                  })}
                </div>
              </div>
            )}

            {pttState === 'busy' && (
              <div className="p-2.5 bg-rose-950/90 border border-rose-500/60 rounded-xl text-center text-rose-200 text-xs font-mono animate-pulse flex items-center justify-center gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-400" />
                <span>FRECUENCIA OCUPADA POR: <strong>{activeSpeaker?.name || 'OPERADOR'}</strong></span>
              </div>
            )}

            {pttState === 'idle' && (
              <div className="flex items-center justify-between text-[10px] text-zinc-400 font-mono">
                <span>EN ESCUCHA • SQUELCH AUTO</span>
                <span className="text-red-400 font-bold flex items-center gap-1">
                  <Hand className="w-3 h-3" /> Deslizar ◄ ► canal
                </span>
              </div>
            )}
          </div>
        </motion.div>

        {/* Dynamic Tactile 60% Screen PTT Button */}
        <div className="w-full flex-1 min-h-[290px] sm:min-h-[360px] flex flex-col justify-center items-center py-1 relative">
          <motion.button
            type="button"
            onMouseDown={handlePttStart}
            onMouseUp={handlePttEnd}
            onMouseLeave={handlePttEnd}
            onTouchStart={handlePttStart}
            onTouchEnd={handlePttEnd}
            whileTap={{ scale: 0.96 }}
            id="btn-ptt-giant"
            className={`w-full h-full max-h-[400px] rounded-3xl font-extrabold flex flex-col items-center justify-center relative shadow-[0_0_80px_rgba(0,0,0,0.8)] border-[8px] sm:border-[10px] transition-all duration-200 cursor-pointer touch-none select-none overflow-hidden ${
              pttState === 'talking'
                ? 'bg-red-500 text-zinc-950 border-red-400 scale-[0.98]'
                : pttState === 'busy'
                ? 'bg-rose-700 text-white border-rose-500 cursor-not-allowed opacity-95'
                : 'bg-zinc-900 text-zinc-100 border-zinc-800 hover:border-red-500/60'
            }`}
          >
            {/* Inner Texture & Glow */}
            <div className={`absolute inset-0 transition-opacity duration-200 ${
              pttState === 'talking'
                ? 'bg-gradient-to-tr from-red-600 to-red-400 opacity-100'
                : pttState === 'busy'
                ? 'bg-gradient-to-tr from-rose-800 to-rose-600 opacity-100'
                : 'bg-gradient-to-b from-zinc-800 via-zinc-900 to-black'
            }`} />

            {/* Glowing Ring Effect on Talk */}
            {pttState === 'talking' && (
              <div className="absolute inset-0 border-8 border-red-300/60 rounded-3xl animate-ping pointer-events-none" />
            )}

            {/* Icon & Label */}
            <div className="relative z-10 flex flex-col items-center gap-3 px-6 text-center">
              <div className={`p-5 rounded-full border-2 transition-transform duration-200 ${
                pttState === 'talking'
                  ? 'bg-zinc-950 text-red-400 border-zinc-950 scale-110 shadow-lg'
                  : pttState === 'busy'
                  ? 'bg-rose-950 text-rose-300 border-rose-400'
                  : 'bg-zinc-950 text-red-400 border-red-500/40'
              }`}>
                {pttState === 'busy' ? (
                  <Lock className="w-12 h-12" />
                ) : (
                  <Radio className={`w-12 h-12 ${pttState === 'talking' ? 'animate-bounce' : ''}`} />
                )}
              </div>

              <div>
                <span className={`text-3xl sm:text-4xl font-black font-mono tracking-wider uppercase block ${
                  pttState === 'talking' ? 'text-zinc-950' : 'text-white'
                }`}>
                  {pttState === 'talking'
                    ? 'HABLANDO'
                    : pttState === 'busy'
                    ? 'OCUPADO'
                    : 'PUSH TO TALK'}
                </span>

                <span className={`text-xs font-semibold tracking-wide block mt-1 ${
                  pttState === 'talking' ? 'text-zinc-900 font-bold' : 'text-zinc-400'
                }`}>
                  {pttState === 'talking'
                    ? 'Transmitiendo audio en vivo'
                    : pttState === 'busy'
                    ? 'Frecuencia ocupada'
                    : 'Mantener presionado para transmitir'}
                </span>
              </div>
            </div>

            {/* Bottom Bezel Metallic Strip */}
            <div className="absolute bottom-3 left-1/2 -translate-x-1/2 text-[10px] font-mono tracking-widest uppercase text-zinc-400 bg-zinc-950 px-3 py-1 rounded-full border border-zinc-800">
              HANDY App By MasAlto • PTT 60% SCREEN
            </div>
          </motion.button>
        </div>

        {/* Channel Switcher Buttons */}
        <div className="w-full grid grid-cols-4 gap-1.5 pt-1">
          {CHANNELS.map((ch, idx) => {
            const isActive = idx === currentChannelIndex;
            return (
              <button
                key={ch.id}
                onClick={() => handleSelectChannel(idx)}
                className={`py-2 rounded-xl text-xs font-mono font-bold border transition text-center cursor-pointer ${
                  isActive
                    ? 'bg-red-500 text-zinc-950 border-red-400 shadow-[0_0_12px_rgba(239,68,68,0.4)]'
                    : 'bg-zinc-900 text-zinc-300 border-zinc-800 hover:bg-zinc-800'
                }`}
              >
                {ch.code}
              </button>
            );
          })}
        </div>
      </main>

      {/* Footer Status Line */}
      <footer className="max-w-lg mx-auto w-full pt-1 z-10 flex justify-between items-center text-[10px] font-bold font-mono tracking-wider uppercase text-zinc-400 bg-zinc-950 px-3 py-1.5 rounded-xl border border-zinc-800">
        <span className="flex items-center gap-1.5 text-red-400">
          <span className="w-1.5 h-1.5 rounded-full bg-red-500"></span>
          CANAL {currentChannel.code} ACTIVO
        </span>
        <div className="flex gap-2">
          <button 
            onClick={() => setIsAudioFeedOpen(true)}
            className="bg-red-500/20 text-red-400 hover:bg-red-500/30 px-2 py-0.5 rounded border border-red-500/30 flex items-center gap-1 transition cursor-pointer"
          >
            <Headphones className="w-3 h-3" /> AUDIO FEED ({recordings.filter(r => r.channel_code === currentChannel.code).length})
          </button>
          <span className="bg-zinc-900 text-red-400 px-2 py-0.5 rounded border border-zinc-800">LIVEKIT SYNC</span>
        </div>
      </footer>

      {/* Audio Feed Modal Drawer */}
      {isAudioFeedOpen && (
        <div className="fixed inset-0 z-50 bg-zinc-950/85 backdrop-blur-md flex items-center justify-center p-3 sm:p-5 font-sans">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
            <div className="p-4 border-b border-zinc-800 flex items-center justify-between bg-zinc-950/90">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
                  <Headphones className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white flex items-center gap-2">
                    HANDY Audio Feed <span className="text-xs bg-zinc-800 text-red-400 px-2 py-0.5 rounded border border-zinc-700 font-mono">By MasAlto</span>
                  </h3>
                  <p className="text-xs text-zinc-400">Historial de órdenes de voz, transcripciones y repeticiones</p>
                </div>
              </div>

              <button
                onClick={() => setIsAudioFeedOpen(false)}
                className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-3 sm:p-4 overflow-y-auto flex-1">
              <AudioFeed
                recordings={recordings}
                activeChannelCode={currentChannel.code}
                onClearRecordings={() => setRecordings([])}
                onAddSampleRecording={handleAddSampleRecording}
              />
            </div>
          </div>
        </div>
      )}

      {/* Logging Proposal Modal */}
      <LoggingProposalModal
        isOpen={isLoggingProposalOpen}
        onClose={() => setIsLoggingProposalOpen(false)}
      />

      {/* Channel Analytics & Bottleneck Heatmap Modal */}
      <ChannelAnalyticsModal
        isOpen={isAnalyticsOpen}
        onClose={() => setIsAnalyticsOpen(false)}
        recordings={recordings}
        channels={CHANNELS}
      />
    </div>
  );
};

