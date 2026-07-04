import React, { useState } from 'react';
import { Database, Copy, Check, X, ShieldAlert, Sparkles } from 'lucide-react';
import { getSupabaseConfig, saveSupabaseConfig } from '../services/supabaseClient';

interface SqlMigrationModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SQL_MIGRATION_SCRIPT = `-- ====================================================================
-- SUPABASE MIGRATION SCRIPT & RLS POLICIES FOR EVENT RADIO APP
-- Activa RLS en las tablas messages, participants y logs_operativos.
-- Asegura que un usuario solo pueda leer/escribir mensajes si su auth.uid()
-- existe en la tabla participants para el event_id correspondiente.
-- ====================================================================

-- 1. Crear extensión uuid si no existe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tabla de Eventos
CREATE TABLE IF NOT EXISTS public.events (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  venue text,
  invite_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Insertar evento demo con código 123456
INSERT INTO public.events (id, name, venue, invite_code)
VALUES ('11111111-1111-1111-1111-111111111111', 'Festival Lollapalooza 2026', 'Hipódromo San Isidro', '123456')
ON CONFLICT (invite_code) DO NOTHING;

-- 3. Tabla de Participantes (participants)
CREATE TABLE IF NOT EXISTS public.participants (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  role text NOT NULL,
  channel_id text DEFAULT 'CH-01',
  is_online boolean DEFAULT true,
  is_talking boolean DEFAULT false,
  joined_at timestamptz DEFAULT now(),
  UNIQUE(event_id, user_id)
);

-- 4. Tabla de Mensajes / Transmisiones (messages)
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  channel_id text NOT NULL,
  sender_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  sender_name text NOT NULL,
  sender_role text NOT NULL,
  audio_url text,
  transcript text,
  duration_ms integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- 5. Tabla de Logs Operativos (logs_operativos)
CREATE TABLE IF NOT EXISTS public.logs_operativos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id text,
  user_id text,
  user_name text,
  user_role text,
  channel_id text,
  event_type text NOT NULL,
  details jsonb,
  timestamp timestamptz DEFAULT now()
);

-- ====================================================================
-- HABILITAR ROW LEVEL SECURITY (RLS)
-- ====================================================================

ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_operativos ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------
-- POLÍTICAS RLS PARA TABLA 'participants'
-- --------------------------------------------------------------------

-- Permite leer participantes si perteneces al mismo evento o es tu usuario
CREATE POLICY "Participants: Lectura autorizada por evento"
ON public.participants FOR SELECT
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM public.participants p
    WHERE p.event_id = participants.event_id
      AND p.user_id = auth.uid()
  )
);

-- Permite unirse/registrarse como participante
CREATE POLICY "Participants: Inserción de participante propio"
ON public.participants FOR INSERT
WITH CHECK (
  auth.uid() = user_id
);

-- --------------------------------------------------------------------
-- POLÍTICAS RLS PARA TABLA 'messages' (Muestra la regla solicitada)
-- Un usuario SOLO puede LEER si su auth.uid() existe en participants
-- para el event_id correspondiente.
-- --------------------------------------------------------------------

CREATE POLICY "Messages: Lectura restringida a participantes del evento"
ON public.messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.participants p
    WHERE p.event_id = messages.event_id
      AND p.user_id = auth.uid()
  )
);

-- Un usuario SOLO puede ESCRIBIR si su auth.uid() existe en participants
-- para el event_id correspondiente y es el emisor.
CREATE POLICY "Messages: Insercion restringida a participantes del evento"
ON public.messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM public.participants p
    WHERE p.event_id = messages.event_id
      AND p.user_id = auth.uid()
  )
);

-- --------------------------------------------------------------------
-- POLÍTICAS RLS PARA 'logs_operativos'
-- --------------------------------------------------------------------
CREATE POLICY "Logs: Inserción pública o de operador registrado"
ON public.logs_operativos FOR INSERT
WITH CHECK (true);

CREATE POLICY "Logs: Lectura para administradores u operadores"
ON public.logs_operativos FOR SELECT
USING (true);

-- ====================================================================
-- FUNCIÓN RPC: validate_invite_code
-- Valida un código de 6 dígitos y retorna el evento correspondiente
-- ====================================================================

CREATE OR REPLACE FUNCTION public.validate_invite_code(code text)
RETURNS TABLE (
  event_id uuid,
  event_name text,
  venue text,
  valid boolean
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT e.id AS event_id, e.name AS event_name, e.venue AS venue, true AS valid
  FROM public.events e
  WHERE e.invite_code = code;
END;
$$;
`;

export const SqlMigrationModal: React.FC<SqlMigrationModalProps> = ({ isOpen, onClose }) => {
  const [copied, setCopied] = useState(false);
  const [activeTab, setActiveTab] = useState<'sql' | 'config'>('sql');

  const config = getSupabaseConfig();
  const [url, setUrl] = useState(config.url);
  const [anonKey, setAnonKey] = useState(config.anonKey);
  const [saveStatus, setSaveStatus] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleCopy = () => {
    navigator.clipboard.writeText(SQL_MIGRATION_SCRIPT);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSaveConfig = (e: React.FormEvent) => {
    e.preventDefault();
    saveSupabaseConfig(url, anonKey);
    setSaveStatus('Credenciales de Supabase guardadas correctamente.');
    setTimeout(() => setSaveStatus(null), 3000);
  };

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950/80 backdrop-blur-sm flex items-center justify-center p-4 font-sans">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-3xl max-h-[85vh] flex flex-col shadow-2xl overflow-hidden">
        
        {/* Header */}
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between bg-zinc-900/90">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white">Configuración Supabase & Script SQL RLS</h3>
              <p className="text-xs text-zinc-400">Activa Row Level Security para `messages` y `participants` por `event_id`</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab switcher */}
        <div className="flex border-b border-zinc-800 bg-zinc-950/60 px-5 pt-3">
          <button
            onClick={() => setActiveTab('sql')}
            className={`pb-2.5 px-4 text-sm font-semibold border-b-2 transition flex items-center gap-2 cursor-pointer ${
              activeTab === 'sql'
                ? 'border-red-400 text-red-400'
                : 'border-transparent text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Sparkles className="w-4 h-4" /> Script SQL (Migración & RLS)
          </button>
          <button
            onClick={() => setActiveTab('config')}
            className={`pb-2.5 px-4 text-sm font-semibold border-b-2 transition flex items-center gap-2 cursor-pointer ${
              activeTab === 'config'
                ? 'border-red-400 text-red-400'
                : 'border-transparent text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Database className="w-4 h-4" /> Conexión Supabase API
          </button>
        </div>

        {/* Content Area */}
        <div className="p-6 overflow-y-auto flex-1 font-sans">
          {activeTab === 'sql' ? (
            <div className="space-y-4">
              <div className="p-3.5 bg-rose-950/30 border border-rose-500/30 rounded-xl text-xs text-red-200 flex items-start gap-2.5">
                <ShieldAlert className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
                <div>
                  <p className="font-bold mb-0.5">Regla RLS Aplicada:</p>
                  <p className="text-zinc-300">
                    Un usuario solo puede leer/escribir en la tabla <code className="bg-zinc-950 px-1 py-0.5 rounded text-red-300">messages</code> si existe una coincidencia de su <code className="bg-zinc-950 px-1 py-0.5 rounded text-red-300">auth.uid()</code> en la tabla <code className="bg-zinc-950 px-1 py-0.5 rounded text-red-300">participants</code> para el correspondiente <code className="bg-zinc-950 px-1 py-0.5 rounded text-red-300">event_id</code>.
                  </p>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-xs text-zinc-400 font-mono">Copiar y ejecutar en el Editor SQL de Supabase:</span>
                <button
                  onClick={handleCopy}
                  id="btn-copy-sql-script"
                  className="px-3 py-1.5 bg-red-500 hover:bg-red-400 text-zinc-950 font-bold text-xs rounded-lg transition flex items-center gap-1.5 shadow cursor-pointer"
                >
                  {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                  <span>{copied ? '¡Copiado al portapapeles!' : 'Copiar Script SQL'}</span>
                </button>
              </div>

              <div className="relative">
                <pre className="bg-zinc-950 p-4 rounded-xl border border-zinc-800 text-xs font-mono text-red-300/90 overflow-x-auto max-h-[350px] leading-relaxed select-text">
                  {SQL_MIGRATION_SCRIPT}
                </pre>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSaveConfig} className="space-y-4 max-w-xl mx-auto py-2">
              <p className="text-xs text-zinc-400">
                Podes conectar un proyecto de Supabase real para ejecutar las funciones RPC y almacenar los logs operativos en tiempo real. Si no ingresás credenciales, la app funciona en modo de simulación offline.
              </p>

              <div>
                <label className="block text-xs font-medium text-zinc-300 mb-1">
                  Supabase Project URL
                </label>
                <input
                  type="url"
                  placeholder="https://xyzcompany.supabase.co"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-zinc-950 border border-zinc-800 focus:border-red-400 rounded-lg text-sm text-white focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-300 mb-1">
                  Supabase Anon Key
                </label>
                <input
                  type="password"
                  placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                  value={anonKey}
                  onChange={(e) => setAnonKey(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-zinc-950 border border-zinc-800 focus:border-red-400 rounded-lg text-sm text-white focus:outline-none"
                />
              </div>

              {saveStatus && (
                <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-lg text-red-300 text-xs">
                  {saveStatus}
                </div>
              )}

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setUrl('');
                    setAnonKey('');
                    saveSupabaseConfig('', '');
                    setSaveStatus('Modo offline activado.');
                  }}
                  className="px-4 py-2 bg-zinc-800 text-zinc-300 rounded-lg text-xs hover:bg-zinc-700 cursor-pointer"
                >
                  Limpiar / Usar Offline
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-red-500 hover:bg-red-400 text-zinc-950 font-bold rounded-lg text-xs cursor-pointer"
                >
                  Guardar Conexión
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
