import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { 
  Radio, 
  KeyRound, 
  User, 
  Briefcase, 
  ArrowRight, 
  CheckCircle2, 
  Building2, 
  Calendar, 
  Sparkles,
  Database,
  Volume2,
  PlusCircle,
  FileText
} from 'lucide-react';
import { EventDetails, UserRole } from '../types';
import { validateInviteCode, PRESET_EVENTS } from '../services/supabaseClient';
import { LogServicio } from '../services/logService';
import { CreateEventModal } from './CreateEventModal';
import { LoggingProposalModal } from './LoggingProposalModal';

interface AuthScreenProps {
  onSuccess: (event: EventDetails, userName: string, role: UserRole) => void;
  onOpenSqlModal: () => void;
}

const ROLES: { name: UserRole; icon: string; description: string }[] = [
  { name: 'Seguridad', icon: '🛡️', description: 'Control de accesos y perímetro' },
  { name: 'Producción', icon: '🎛️', description: 'Coordinación general de evento' },
  { name: 'Logística', icon: '📦', description: 'Carga, insumos y montaje' },
  { name: 'Médico', icon: '🩺', description: 'Atención sanitaria y emergencias' },
  { name: 'Escenario', icon: '🎤', description: 'Stage managers y sonido' },
  { name: 'Coordinación VIP', icon: '👑', description: 'Hospitality y artistas' },
];

export const AuthScreen: React.FC<AuthScreenProps> = ({ onSuccess, onOpenSqlModal }) => {
  const [inviteCode, setInviteCode] = useState('');
  const [isValidating, setIsValidating] = useState(false);
  const [validatedEvent, setValidatedEvent] = useState<EventDetails | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [userName, setUserName] = useState('');
  const [selectedRole, setSelectedRole] = useState<UserRole>('Producción');

  const [isCreateEventOpen, setIsCreateEventOpen] = useState(false);
  const [isLoggingProposalOpen, setIsLoggingProposalOpen] = useState(false);

  // Handle auto validation when 6 digits are typed
  useEffect(() => {
    if (inviteCode.length === 6 && !validatedEvent && !isValidating) {
      handleValidateCode(inviteCode);
    }
  }, [inviteCode]);

  const handleValidateCode = async (codeToTest: string) => {
    if (codeToTest.length !== 6) {
      setErrorMsg('Por favor ingresa los 6 dígitos del código.');
      return;
    }

    setIsValidating(true);
    setErrorMsg(null);

    try {
      const result = await validateInviteCode(codeToTest);
      if (result.success && result.event) {
        setValidatedEvent(result.event);
        LogServicio.setContext({ eventId: result.event.id });
        LogServicio.logEvent('INVITE_CODE_VALIDATED', {
          code: codeToTest,
          event_name: result.event.name,
        });
      } else {
        setErrorMsg(result.error || 'Código inválido o caducado.');
      }
    } catch (err: any) {
      setErrorMsg('Error al conectar con la función RPC de Supabase.');
    } finally {
      setIsValidating(false);
    }
  };

  const handlePresetClick = (code: string) => {
    setInviteCode(code);
    handleValidateCode(code);
  };

  const handleEventCreated = (newEvent: EventDetails) => {
    setValidatedEvent(newEvent);
    setInviteCode(newEvent.invite_code);
  };

  const handleFinalSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!validatedEvent) return;

    const finalName = userName.trim() || `Operador #${Math.floor(100 + Math.random() * 900)}`;
    
    LogServicio.setContext({
      userName: finalName,
      userRole: selectedRole,
      eventId: validatedEvent.id,
    });

    onSuccess(validatedEvent, finalName, selectedRole);
  };

  return (
    <div className="min-h-screen bg-black text-zinc-100 flex flex-col justify-between p-4 sm:p-6 relative overflow-hidden select-none font-sans">
      {/* Background Ambient Glow */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-red-500/10 blur-[120px] rounded-full pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-[300px] h-[300px] bg-rose-500/10 blur-[100px] rounded-full pointer-events-none" />

      {/* Top Header */}
      <header className="flex flex-wrap justify-between items-center max-w-xl mx-auto w-full pt-2 z-10 gap-3">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30 shadow-lg shadow-red-500/10">
            <Radio className="w-6 h-6 animate-pulse" />
          </div>
          <div>
            <h1 className="text-xl font-extrabold tracking-tight text-white flex items-center gap-2">
              HANDY <span className="text-red-400 font-mono text-sm">By MasAlto</span>
            </h1>
            <p className="text-xs text-zinc-400">Coordinación Operativa de Eventos PTT</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsLoggingProposalOpen(true)}
            id="btn-open-logging-proposal"
            className="text-xs flex items-center gap-1.5 px-3 py-1.5 bg-zinc-900 hover:bg-zinc-800 text-red-400 rounded-lg border border-zinc-800 hover:border-red-500/40 transition cursor-pointer font-mono font-bold"
            title="Ver propuesta de logging e infraestructura MasAlto"
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Propuesta Logging</span>
          </button>

          <button
            onClick={onOpenSqlModal}
            id="btn-open-sql-migration"
            className="text-xs flex items-center gap-1.5 px-3 py-1.5 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 rounded-lg border border-zinc-800 transition cursor-pointer"
            title="Ver migración SQL y políticas RLS Supabase"
          >
            <Database className="w-3.5 h-3.5 text-red-400" />
            <span>Esquema SQL</span>
          </button>
        </div>
      </header>

      {/* Main Single-Screen Form Container */}
      <main className="max-w-xl mx-auto w-full my-auto py-6 z-10">
        <div className="bg-zinc-950/90 backdrop-blur-md rounded-2xl border border-zinc-800 p-6 sm:p-8 shadow-2xl relative">
          
          {/* Header Step Indicator */}
          <div className="mb-6 border-b border-zinc-800 pb-4 flex items-center justify-between">
            <div>
              <span className="text-xs font-mono tracking-wider uppercase text-red-400 font-bold block mb-1">
                {validatedEvent ? 'PASO 2 DE 2 • ROL Y OPERADOR' : 'PASO 1 DE 2 • CÓDIGO DE INGRESO'}
              </span>
              <h2 className="text-2xl font-bold text-white">
                {validatedEvent ? 'Configurar Credencial de Frecuencia' : 'Ingresá el Código de Invitación'}
              </h2>
            </div>

            {!validatedEvent && (
              <button
                type="button"
                onClick={() => setIsCreateEventOpen(true)}
                id="btn-trigger-create-event"
                className="px-3 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 border border-red-500/40 rounded-xl text-xs font-bold transition flex items-center gap-1.5 cursor-pointer shrink-0"
              >
                <PlusCircle className="w-4 h-4" />
                <span>Crear Evento</span>
              </button>
            )}
          </div>

          {/* STAGE 1: GIANT 6-DIGIT INPUT */}
          {!validatedEvent ? (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
              className="space-y-6"
            >
              <div>
                <label className="block text-sm text-zinc-300 mb-2 font-medium flex items-center justify-between">
                  <span>Código de 6 dígitos</span>
                  <span className="text-xs text-zinc-400 font-normal">Validación por Supabase RPC</span>
                </label>

                {/* Giant Digit Input Box */}
                <div className="relative">
                  <input
                    type="text"
                    inputMode="numeric"
                    maxLength={6}
                    value={inviteCode}
                    onChange={(e) => {
                      const clean = e.target.value.replace(/\D/g, '').slice(0, 6);
                      setInviteCode(clean);
                      setErrorMsg(null);
                    }}
                    placeholder="123456"
                    id="input-invite-code"
                    className="w-full tracking-[0.5em] sm:tracking-[0.8em] font-mono text-center text-3xl sm:text-4xl py-4 sm:py-5 bg-black border-2 border-red-500/40 focus:border-red-400 rounded-xl text-red-300 font-bold focus:outline-none focus:ring-4 focus:ring-red-500/20 shadow-inner transition"
                    autoFocus
                  />
                  <KeyRound className="absolute right-4 top-1/2 -translate-y-1/2 w-6 h-6 text-zinc-600 pointer-events-none" />
                </div>

                {/* Display Individual Digit Boxes indicator */}
                <div className="grid grid-cols-6 gap-2 mt-3">
                  {[0, 1, 2, 3, 4, 5].map((idx) => {
                    const char = inviteCode[idx];
                    return (
                      <div
                        key={idx}
                        className={`h-2 rounded-full transition-all duration-300 ${
                          char
                            ? 'bg-red-500 shadow-sm shadow-red-500/50'
                            : 'bg-zinc-800'
                        }`}
                      />
                    );
                  })}
                </div>
              </div>

              {/* Error Alert */}
              {errorMsg && (
                <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl text-rose-300 text-xs flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-rose-500 animate-ping" />
                  <span>{errorMsg}</span>
                </div>
              )}

              {/* Action Button */}
              <button
                type="button"
                onClick={() => handleValidateCode(inviteCode)}
                disabled={inviteCode.length !== 6 || isValidating}
                id="btn-validate-rpc"
                className="w-full py-4 bg-red-500 hover:bg-red-400 disabled:bg-zinc-800 disabled:text-zinc-500 text-zinc-950 font-bold text-lg rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-red-500/20 cursor-pointer disabled:cursor-not-allowed"
              >
                {isValidating ? (
                  <>
                    <div className="w-5 h-5 border-2 border-zinc-950 border-t-transparent rounded-full animate-spin" />
                    <span>Llamando Supabase RPC...</span>
                  </>
                ) : (
                  <>
                    <span>Validar Código</span>
                    <ArrowRight className="w-5 h-5" />
                  </>
                )}
              </button>

              {/* Demo Quick Codes Selector & Create Event trigger */}
              <div className="pt-4 border-t border-zinc-800">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-xs text-zinc-400 font-medium flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                    <span>Eventos demo preconfigurados:</span>
                  </p>
                  <button
                    type="button"
                    onClick={() => setIsCreateEventOpen(true)}
                    className="text-xs text-red-400 hover:underline flex items-center gap-1 font-semibold cursor-pointer"
                  >
                    <PlusCircle className="w-3.5 h-3.5" /> Nuevo Evento
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  {Object.values(PRESET_EVENTS).map((evt) => (
                    <button
                      key={evt.invite_code}
                      type="button"
                      onClick={() => handlePresetClick(evt.invite_code)}
                      id={`btn-preset-${evt.invite_code}`}
                      className="text-left p-2.5 bg-black/80 hover:bg-zinc-900 border border-zinc-800 hover:border-red-500/50 rounded-lg text-xs transition group cursor-pointer"
                    >
                      <div className="font-mono text-red-400 font-bold flex items-center justify-between">
                        <span>{evt.invite_code}</span>
                        <span className="text-[10px] text-zinc-500 group-hover:text-red-300">Cargar</span>
                      </div>
                      <div className="text-zinc-300 font-medium truncate mt-0.5">{evt.name}</div>
                    </button>
                  ))}
                </div>
              </div>
            </motion.div>
          ) : (
            /* STAGE 2: UNVEILED NAME + ROLE INPUT FORM */
            <motion.form
              onSubmit={handleFinalSubmit}
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.35 }}
              className="space-y-6"
            >
              {/* Event Verified Card */}
              <div className="p-4 bg-rose-950/40 border border-rose-500/40 rounded-xl relative overflow-hidden">
                <div className="flex items-start justify-between">
                  <div className="space-y-1">
                    <span className="inline-flex items-center gap-1 text-[11px] font-bold uppercase tracking-wider text-red-400 bg-red-500/20 px-2 py-0.5 rounded">
                      <CheckCircle2 className="w-3.5 h-3.5" /> Evento Verificado por RPC
                    </span>
                    <h3 className="text-lg font-bold text-white leading-tight">{validatedEvent.name}</h3>
                    <div className="text-xs text-zinc-300 flex items-center gap-3 pt-1">
                      <span className="flex items-center gap-1 text-zinc-400">
                        <Building2 className="w-3.5 h-3.5 text-red-400" /> {validatedEvent.venue}
                      </span>
                      <span className="flex items-center gap-1 text-zinc-400">
                        <Calendar className="w-3.5 h-3.5 text-red-400" /> {validatedEvent.date}
                      </span>
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => {
                      setValidatedEvent(null);
                      setInviteCode('');
                    }}
                    className="text-xs text-zinc-400 hover:text-white underline cursor-pointer"
                  >
                    Cambiar
                  </button>
                </div>
              </div>

              {/* Name Field */}
              <div>
                <label className="block text-sm text-zinc-300 mb-1.5 font-medium flex items-center gap-1.5">
                  <User className="w-4 h-4 text-red-400" />
                  <span>Nombre / Identificador Operativo</span>
                </label>
                <input
                  type="text"
                  required
                  value={userName}
                  onChange={(e) => setUserName(e.target.value)}
                  placeholder="Ej: Carlos M. / Escenario 1"
                  id="input-operator-name"
                  className="w-full px-4 py-3 bg-black border border-zinc-700 focus:border-red-400 rounded-xl text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-red-500/20 transition font-sans"
                  autoFocus
                />
              </div>

              {/* Role Selection Grid */}
              <div>
                <label className="block text-sm text-zinc-300 mb-2 font-medium flex items-center gap-1.5">
                  <Briefcase className="w-4 h-4 text-red-400" />
                  <span>Seleccionar Rol Operativo</span>
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                  {ROLES.map((role) => {
                    const isSelected = selectedRole === role.name;
                    return (
                      <button
                        key={role.name}
                        type="button"
                        onClick={() => setSelectedRole(role.name)}
                        id={`role-btn-${role.name}`}
                        className={`p-3 rounded-xl border text-left transition flex flex-col justify-between cursor-pointer ${
                          isSelected
                            ? 'bg-red-500/20 border-red-400 text-white shadow-md shadow-red-500/10'
                            : 'bg-black border-zinc-800 text-zinc-400 hover:border-zinc-700 hover:text-zinc-200'
                        }`}
                      >
                        <div className="text-2xl mb-1">{role.icon}</div>
                        <div>
                          <div className={`font-bold text-sm ${isSelected ? 'text-red-300' : 'text-zinc-200'}`}>
                            {role.name}
                          </div>
                          <div className="text-[10px] text-zinc-400 line-clamp-1">{role.description}</div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Final Submit Button */}
              <button
                type="submit"
                id="btn-enter-handy"
                className="w-full py-4 bg-red-500 hover:bg-red-400 text-zinc-950 font-bold text-lg rounded-xl transition flex items-center justify-center gap-2 shadow-xl shadow-red-500/25 cursor-pointer"
              >
                <Volume2 className="w-5 h-5" />
                <span>Sintonizar Frecuencia Handy</span>
              </button>
            </motion.form>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="text-center text-xs text-zinc-500 max-w-xl mx-auto w-full pb-2 z-10 font-mono">
        <p>HANDY App By MasAlto • Sistema PTT Operativo • Supabase RLS Protected</p>
      </footer>

      {/* Create Event Modal */}
      <CreateEventModal
        isOpen={isCreateEventOpen}
        onClose={() => setIsCreateEventOpen(false)}
        onEventCreated={handleEventCreated}
      />

      {/* Logging Proposal Modal */}
      <LoggingProposalModal
        isOpen={isLoggingProposalOpen}
        onClose={() => setIsLoggingProposalOpen(false)}
      />
    </div>
  );
};
