import React, { useState } from 'react';
import { 
  PlusCircle, 
  X, 
  Building2, 
  Calendar, 
  KeyRound, 
  Radio, 
  Check, 
  Sparkles,
  Layers
} from 'lucide-react';
import { EventDetails } from '../types';
import { PRESET_EVENTS } from '../services/supabaseClient';
import { LogServicio } from '../services/logService';

interface CreateEventModalProps {
  isOpen: boolean;
  onClose: () => void;
  onEventCreated: (event: EventDetails) => void;
}

export const CreateEventModal: React.FC<CreateEventModalProps> = ({
  isOpen,
  onClose,
  onEventCreated,
}) => {
  const getRandomCode = () => Math.floor(100000 + Math.random() * 900000).toString();

  const [eventName, setEventName] = useState('');
  const [venue, setVenue] = useState('');
  const [date, setDate] = useState('4 de Julio, 2026');
  const [inviteCode, setInviteCode] = useState(getRandomCode());
  const [channelsCount, setChannelsCount] = useState(4);
  const [isSuccess, setIsSuccess] = useState(false);

  if (!isOpen) return null;

  const handleGenerateNewCode = () => {
    setInviteCode(getRandomCode());
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!eventName.trim() || !venue.trim() || inviteCode.length !== 6) return;

    const newEvent: EventDetails = {
      id: `evt-custom-${Date.now()}`,
      name: eventName.trim(),
      venue: venue.trim(),
      invite_code: inviteCode,
      date: date.trim() || new Date().toLocaleDateString('es-AR'),
      channels_count: channelsCount,
    };

    // Store in global PRESET_EVENTS map for instant RPC/lookup resolution
    PRESET_EVENTS[inviteCode] = newEvent;

    LogServicio.setContext({ eventId: newEvent.id });
    LogServicio.logEvent('INVITE_CODE_VALIDATED', {
      action: 'CREATE_EVENT',
      event_name: newEvent.name,
      code: inviteCode,
      venue: newEvent.venue,
    });

    setIsSuccess(true);

    setTimeout(() => {
      setIsSuccess(false);
      onEventCreated(newEvent);
      onClose();
    }, 800);
  };

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950/85 backdrop-blur-md flex items-center justify-center p-4 font-sans select-none">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden text-zinc-100 relative">
        
        {/* Header */}
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between bg-zinc-950/90">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
              <PlusCircle className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                Crear Nuevo Evento <span className="text-xs bg-red-500/20 text-red-400 px-2 py-0.5 rounded border border-red-500/30 font-mono">MasAlto</span>
              </h3>
              <p className="text-xs text-zinc-400">Genera la frecuencia de radio y el código único de 6 dígitos</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          
          {/* Event Name */}
          <div>
            <label className="block text-xs font-bold text-zinc-300 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
              <Radio className="w-3.5 h-3.5 text-red-400" />
              <span>Nombre del Evento</span>
            </label>
            <input
              type="text"
              required
              value={eventName}
              onChange={(e) => setEventName(e.target.value)}
              placeholder="Ej: Concierto Costa Salguero 2026"
              className="w-full px-3.5 py-2.5 bg-zinc-950 border border-zinc-700 focus:border-red-400 rounded-xl text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-red-500/20 text-sm font-sans"
              autoFocus
            />
          </div>

          {/* Venue & Location */}
          <div>
            <label className="block text-xs font-bold text-zinc-300 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
              <Building2 className="w-3.5 h-3.5 text-red-400" />
              <span>Predio / Estadio / Recinto</span>
            </label>
            <input
              type="text"
              required
              value={venue}
              onChange={(e) => setVenue(e.target.value)}
              placeholder="Ej: Estadio Mâs Monumental - Núñez"
              className="w-full px-3.5 py-2.5 bg-zinc-950 border border-zinc-700 focus:border-red-400 rounded-xl text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-red-500/20 text-sm font-sans"
            />
          </div>

          {/* Date & Channels Count */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold text-zinc-300 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-red-400" />
                <span>Fecha del Evento</span>
              </label>
              <input
                type="text"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                placeholder="Ej: 4 de Julio, 2026"
                className="w-full px-3 py-2.5 bg-zinc-950 border border-zinc-700 focus:border-red-400 rounded-xl text-white text-xs font-sans"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-zinc-300 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5 text-red-400" />
                <span>Nº Canales PTT</span>
              </label>
              <select
                value={channelsCount}
                onChange={(e) => setChannelsCount(Number(e.target.value))}
                className="w-full px-3 py-2.5 bg-zinc-950 border border-zinc-700 focus:border-red-400 rounded-xl text-white text-xs font-sans"
              >
                <option value={3}>3 Canales</option>
                <option value={4}>4 Canales (Estándar)</option>
                <option value={5}>5 Canales (Avanzado)</option>
                <option value={6}>6 Canales (Gran Recinto)</option>
              </select>
            </div>
          </div>

          {/* Auto Generated 6-Digit Code */}
          <div className="p-4 bg-zinc-950 border border-red-500/30 rounded-xl space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="font-bold text-zinc-300 flex items-center gap-1.5">
                <KeyRound className="w-4 h-4 text-red-400" />
                <span>Código de Invitación de 6 Dígitos</span>
              </span>
              <button
                type="button"
                onClick={handleGenerateNewCode}
                className="text-red-400 hover:underline flex items-center gap-1 cursor-pointer font-mono"
              >
                <Sparkles className="w-3 h-3" /> Regenerar
              </button>
            </div>

            <div className="flex items-center justify-center gap-2 py-1">
              <input
                type="text"
                maxLength={6}
                value={inviteCode}
                onChange={(e) => setInviteCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="text-center font-mono text-2xl font-bold tracking-widest bg-zinc-900 border border-red-500/40 rounded-lg text-red-300 py-1.5 w-44 focus:outline-none"
              />
            </div>
            <p className="text-[11px] text-zinc-400 text-center">
              Comparte este código con tu equipo de producción y seguridad para ingresar a este canal.
            </p>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={!eventName.trim() || !venue.trim() || inviteCode.length !== 6 || isSuccess}
            id="btn-confirm-create-event"
            className="w-full py-3.5 bg-red-500 hover:bg-red-400 disabled:bg-zinc-800 disabled:text-zinc-500 text-zinc-950 font-bold text-base rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-red-500/20 cursor-pointer disabled:cursor-not-allowed mt-2"
          >
            {isSuccess ? (
              <>
                <Check className="w-5 h-5 text-zinc-950" />
                <span>¡Evento Creado Con Éxito!</span>
              </>
            ) : (
              <>
                <PlusCircle className="w-5 h-5" />
                <span>Crear Evento y Sintonizar Frecuencia</span>
              </>
            )}
          </button>
        </form>

      </div>
    </div>
  );
};
