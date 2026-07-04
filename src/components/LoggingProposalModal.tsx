import React from 'react';
import { 
  ShieldCheck, 
  X, 
  FileText, 
  Database, 
  Wifi, 
  Radio, 
  AlertTriangle, 
  Clock, 
  Cpu, 
  CheckCircle2,
  Lock,
  Zap,
  Layers
} from 'lucide-react';

interface LoggingProposalModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const LoggingProposalModal: React.FC<LoggingProposalModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950/85 backdrop-blur-md flex items-center justify-center p-3 sm:p-5 font-sans">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-3xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden text-zinc-100">
        
        {/* Header */}
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between bg-zinc-950/90">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base sm:text-lg font-bold text-white flex items-center gap-2">
                Propuesta de Logging e Infraestructura <span className="text-xs bg-red-500/20 text-red-400 px-2 py-0.5 rounded border border-red-500/30 font-mono">By MasAlto</span>
              </h3>
              <p className="text-xs text-zinc-400">Arquitectura de telemetría, auditoría post-evento y resiliencia offline</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-5 overflow-y-auto space-y-6 flex-1 text-xs sm:text-sm leading-relaxed">
          
          {/* Executive Summary Banner */}
          <div className="p-4 bg-rose-950/30 border border-rose-500/30 rounded-xl flex items-start gap-3">
            <ShieldCheck className="w-6 h-6 text-red-400 shrink-0 mt-0.5" />
            <div>
              <h4 className="font-bold text-red-300 text-sm">Resumen Ejecutivo de Auditoría & Logging</h4>
              <p className="text-zinc-300 mt-1">
                HANDY App By MasAlto implementa un modelo de <strong>Logging Desacoplado en Lotes (Batch Offloading)</strong>. Permite capturar eventos críticos sin bloquear el hilo principal de audio en vivo ni depender de una conexión celular 100% estable en estadios o predios masivos.
              </p>
            </div>
          </div>

          {/* Pillars Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            
            {/* Pillar 1 */}
            <div className="p-4 bg-zinc-950/70 border border-zinc-800 rounded-xl space-y-2">
              <div className="flex items-center gap-2 text-red-400 font-bold">
                <Lock className="w-4 h-4" />
                <span>1. Atribución Criptográfica & RLS</span>
              </div>
              <p className="text-zinc-400 text-xs">
                Cada ráfaga PTT, cambio de canal y alerta SOS incluye firma del <code>user_id</code>, <code>event_id</code>, rol operativo y marca de tiempo ISO-8601 UTC. Las políticas Row Level Security en Supabase impiden la alteración de registros.
              </p>
              <div className="text-[10px] font-mono bg-zinc-900 p-2 rounded text-zinc-300 border border-zinc-800">
                <code>INSERT INTO logs_operativos (event_id, user_role, event_type)</code>
              </div>
            </div>

            {/* Pillar 2 */}
            <div className="p-4 bg-zinc-950/70 border border-zinc-800 rounded-xl space-y-2">
              <div className="flex items-center gap-2 text-red-400 font-bold">
                <Zap className="w-4 h-4" />
                <span>2. Buffer Offline en Recintos Congestionados</span>
              </div>
              <p className="text-zinc-400 text-xs">
                Si la señal 4G/5G cae durante el show, la aplicación acumula las métricas en <code>localStorage</code> sin interferir con la voz. Al restablecer el enlace, un cron inteligente envía el lote automáticamente a PostgreSQL.
              </p>
              <div className="text-[10px] font-mono bg-zinc-900 p-2 rounded text-red-400 border border-zinc-800 flex items-center justify-between">
                <span>Retención Local: Activa</span>
                <span className="bg-red-500/20 text-red-300 px-1.5 py-0.5 rounded">Intervalo: 8s</span>
              </div>
            </div>

            {/* Pillar 3 */}
            <div className="p-4 bg-zinc-950/70 border border-zinc-800 rounded-xl space-y-2">
              <div className="flex items-center gap-2 text-red-400 font-bold">
                <Radio className="w-4 h-4" />
                <span>3. Audio Feed & Transcripción Instantánea</span>
              </div>
              <p className="text-zinc-400 text-xs">
                Integración de Speech-to-Text para convertir órdenes de voz en texto. Permite a los productores buscar palabras clave ("evacuación", "puerta 3", "artista en camarín") y reproducir fragmentos con efecto de radio.
              </p>
              <div className="text-[10px] font-mono bg-zinc-900 p-2 rounded text-zinc-300 border border-zinc-800 flex items-center gap-2">
                <CheckCircle2 className="w-3.5 h-3.5 text-red-400" /> Transcripción en tiempo real lista
              </div>
            </div>

            {/* Pillar 4 */}
            <div className="p-4 bg-zinc-950/70 border border-zinc-800 rounded-xl space-y-2">
              <div className="flex items-center gap-2 text-amber-400 font-bold">
                <AlertTriangle className="w-4 h-4" />
                <span>4. Telemetría S.O.S & Métricas de Latencia</span>
              </div>
              <p className="text-zinc-400 text-xs">
                Monitoreo continuo de latencia del WebSocket WebRTC (&lt;45ms ideal). Ante incidentes graves, las alertas S.O.S saltan el buffer regular y se despachan con prioridad absoluta a la central de seguridad.
              </p>
              <div className="text-[10px] font-mono bg-zinc-900 p-2 rounded text-zinc-300 border border-zinc-800 flex items-center justify-between">
                <span>Latencia de red: 28ms</span>
                <span className="text-red-400 font-bold">SQUELCH OK</span>
              </div>
            </div>

          </div>

          {/* Infrastructure Specifications table */}
          <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-950/90">
            <div className="p-3 bg-zinc-900 border-b border-zinc-800 font-bold text-xs uppercase text-zinc-300 flex items-center gap-2">
              <Layers className="w-4 h-4 text-red-400" />
              <span>Especificación Técnica MasAlto</span>
            </div>
            <div className="divide-y divide-zinc-800/80 text-xs">
              <div className="p-2.5 flex justify-between">
                <span className="text-zinc-400">Motor PTT Voice Engine:</span>
                <span className="font-mono text-red-400">LiveKit / WebRTC Audio SDK</span>
              </div>
              <div className="p-2.5 flex justify-between">
                <span className="text-zinc-400">Persistencia y Log Database:</span>
                <span className="font-mono text-zinc-200">Supabase PostgreSQL + RLS</span>
              </div>
              <div className="p-2.5 flex justify-between">
                <span className="text-zinc-400">Manejo de Transmisión Ininterrumpida:</span>
                <span className="font-mono text-zinc-200">60% Pantalla Táctil PTT Ergonomía</span>
              </div>
              <div className="p-2.5 flex justify-between">
                <span className="text-zinc-400">Garantía Operativa MasAlto:</span>
                <span className="font-mono text-red-400">100% Cero interrupciones de audio</span>
              </div>
            </div>
          </div>

        </div>

        {/* Footer Actions */}
        <div className="p-4 border-t border-zinc-800 bg-zinc-950/90 flex justify-end">
          <button
            onClick={onClose}
            className="px-5 py-2 bg-red-500 hover:bg-red-400 text-zinc-950 font-bold rounded-xl text-xs transition cursor-pointer"
          >
            Entendido • Cerrar Propuesta
          </button>
        </div>

      </div>
    </div>
  );
};
