import React from 'react';
import { Radio, AlertOctagon, WifiOff, Volume2, Sparkles } from 'lucide-react';
import { LogServicio } from '../services/logService';

interface SimulatorControlsProps {
  isBusy: boolean;
  onToggleBusy: () => void;
  onSimulateIncomingVoice: (speakerName: string, role: string) => void;
  onEmergencyAlert: () => void;
}

export const SimulatorControls: React.FC<SimulatorControlsProps> = ({
  isBusy,
  onToggleBusy,
  onSimulateIncomingVoice,
  onEmergencyAlert,
}) => {
  const handleSimulateConnectionDrop = () => {
    LogServicio.logConnectionFailure('Fallo de conexión en servidor LiveKit', {
      latencyMs: Math.floor(350 + Math.random() * 200),
      packetLossRatio: '14.2%',
    });
  };

  return (
    <div className="bg-zinc-900/90 border border-zinc-800 rounded-xl p-3 backdrop-blur-md text-xs text-zinc-300 font-sans">
      <div className="flex items-center justify-between mb-2">
        <span className="font-mono text-[11px] uppercase tracking-wider text-red-400 font-bold flex items-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5" /> Tablero de Pruebas y Simulación
        </span>
        <span className="text-[10px] text-zinc-500">Prueba de Estados PTT</span>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        {/* Toggle Busy state */}
        <button
          onClick={onToggleBusy}
          id="btn-sim-toggle-busy"
          className={`p-2 rounded-lg border font-medium flex items-center gap-1.5 transition cursor-pointer ${
            isBusy
              ? 'bg-rose-600 text-white border-rose-500 font-bold animate-pulse'
              : 'bg-zinc-950 hover:bg-zinc-800 text-zinc-300 border-zinc-800'
          }`}
        >
          <Radio className="w-3.5 h-3.5" />
          <span>{isBusy ? 'Liberar Canal (Ocupado)' : 'Ocupar Canal (Rojo)'}</span>
        </button>

        {/* Simulate Incoming Voice */}
        <button
          onClick={() => onSimulateIncomingVoice('Martín G.', 'Seguridad')}
          id="btn-sim-incoming-voice"
          className="p-2 rounded-lg bg-zinc-950 hover:bg-zinc-800 text-zinc-300 border border-zinc-800 font-medium flex items-center gap-1.5 transition cursor-pointer"
        >
          <Volume2 className="w-3.5 h-3.5 text-red-400" />
          <span>Simular Transmisión</span>
        </button>

        {/* Simulate LiveKit Drop */}
        <button
          onClick={handleSimulateConnectionDrop}
          id="btn-sim-drop-connection"
          className="p-2 rounded-lg bg-zinc-950 hover:bg-zinc-800 text-zinc-300 border border-zinc-800 font-medium flex items-center gap-1.5 transition cursor-pointer"
        >
          <WifiOff className="w-3.5 h-3.5 text-amber-400" />
          <span>Simular Fallo LiveKit</span>
        </button>

        {/* Emergency SOS */}
        <button
          onClick={onEmergencyAlert}
          id="btn-sim-emergency-sos"
          className="p-2 rounded-lg bg-rose-950/60 hover:bg-rose-900 border border-rose-500/40 text-rose-300 font-bold flex items-center gap-1.5 transition cursor-pointer"
        >
          <AlertOctagon className="w-3.5 h-3.5 text-rose-400" />
          <span>Alerta S.O.S</span>
        </button>
      </div>
    </div>
  );
};
