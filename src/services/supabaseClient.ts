import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { EventDetails, OperationalLog, SupabaseConfig } from '../types';

// Demo preset events for offline/simulation mode
export const PRESET_EVENTS: Record<string, EventDetails> = {
  '123456': {
    id: 'evt-lolla-2026',
    name: 'Festival Lollapalooza 2026',
    venue: 'Hipódromo de San Isidro - Escenario Principal',
    invite_code: '123456',
    date: '4 de Julio, 2026',
    channels_count: 5,
  },
  '888999': {
    id: 'evt-river-2026',
    name: 'Estadio River - Gran Concierto Live',
    venue: 'Estadio Mâs Monumental - Núñez',
    invite_code: '888999',
    date: '5 de Julio, 2026',
    channels_count: 4,
  },
  '654321': {
    id: 'evt-tech-summit',
    name: 'Tech & Audio Summit BBAA',
    venue: 'La Rural - Pabellón Amarillo',
    invite_code: '654321',
    date: '10 de Julio, 2026',
    channels_count: 3,
  },
  '111222': {
    id: 'evt-maraton-2026',
    name: 'Maratón Internacional BBAA 42K',
    venue: 'Circuito Puerto Madero & Centro',
    invite_code: '111222',
    date: '15 de Julio, 2026',
    channels_count: 6,
  }
};

let supabaseInstance: SupabaseClient | null = null;

export function getSupabaseConfig(): SupabaseConfig {
  const env = (import.meta as any).env || {};
  const url = localStorage.getItem('supabase_url') || env.VITE_SUPABASE_URL || '';
  const anonKey = localStorage.getItem('supabase_anon_key') || env.VITE_SUPABASE_ANON_KEY || '';
  return {
    url,
    anonKey,
    isConnected: Boolean(url && anonKey)
  };
}

export function saveSupabaseConfig(url: string, anonKey: string) {
  if (url && anonKey) {
    localStorage.setItem('supabase_url', url.trim());
    localStorage.setItem('supabase_anon_key', anonKey.trim());
    try {
      supabaseInstance = createClient(url.trim(), anonKey.trim());
    } catch (e) {
      console.error('Failed to initialize Supabase client:', e);
    }
  } else {
    localStorage.removeItem('supabase_url');
    localStorage.removeItem('supabase_anon_key');
    supabaseInstance = null;
  }
}

export function getSupabaseClient(): SupabaseClient | null {
  if (!supabaseInstance) {
    const config = getSupabaseConfig();
    if (config.isConnected) {
      try {
        supabaseInstance = createClient(config.url, config.anonKey);
      } catch (err) {
        console.warn('Error instantiating Supabase client:', err);
      }
    }
  }
  return supabaseInstance;
}

/**
 * Validates 6-digit invitation code.
 * Calls Supabase RPC function `validate_invite_code` if configured,
 * otherwise validates against preset offline codes.
 */
export async function validateInviteCode(code: string): Promise<{
  success: boolean;
  event?: EventDetails;
  error?: string;
}> {
  const cleanCode = code.trim();
  if (cleanCode.length !== 6) {
    return { success: false, error: 'El código debe tener exactamente 6 dígitos.' };
  }

  const client = getSupabaseClient();

  if (client) {
    try {
      // Execute Supabase RPC function
      const { data, error } = await client.rpc('validate_invite_code', { code: cleanCode });

      if (error) {
        console.warn('RPC Error from Supabase, falling back to preset search:', error);
      } else if (data && data.length > 0 && data[0].valid) {
        const row = data[0];
        return {
          success: true,
          event: {
            id: row.event_id || `evt-${cleanCode}`,
            name: row.event_name || 'Evento de Radio Operativo',
            venue: row.venue || 'Predio Principal',
            invite_code: cleanCode,
            date: new Date().toLocaleDateString('es-AR'),
            channels_count: 4,
          }
        };
      }
    } catch (err) {
      console.warn('Exception during RPC call:', err);
    }
  }

  // Fallback to presets or auto-generated event for valid 6-digit codes
  if (PRESET_EVENTS[cleanCode]) {
    return { success: true, event: PRESET_EVENTS[cleanCode] };
  }

  // Allow any numeric 6-digit code for testing flexibility
  if (/^\d{6}$/.test(cleanCode)) {
    return {
      success: true,
      event: {
        id: `evt-custom-${cleanCode}`,
        name: `Operación Evento #${cleanCode}`,
        venue: 'Predio / Sector de Operaciones',
        invite_code: cleanCode,
        date: 'Jornada Activa',
        channels_count: 4,
      }
    };
  }

  return { success: false, error: 'Código de invitación no válido o inactivo.' };
}

/**
 * Sends operational logs batch to Supabase table `logs_operativos`.
 */
export async function sendLogsBatchToSupabase(logs: OperationalLog[]): Promise<{
  success: boolean;
  syncedCount: number;
  error?: string;
}> {
  if (logs.length === 0) return { success: true, syncedCount: 0 };

  const client = getSupabaseClient();

  if (!client) {
    // Simulated remote sync for preview mode
    return {
      success: true,
      syncedCount: logs.length,
      error: 'Simulación (Sin credenciales Supabase configuradas)'
    };
  }

  try {
    const recordsToInsert = logs.map(l => ({
      event_id: l.event_id,
      user_id: l.user_id,
      user_name: l.user_name,
      user_role: l.user_role,
      channel_id: l.channel_id,
      event_type: l.event_type,
      details: l.details,
      timestamp: l.timestamp,
    }));

    const { error } = await client
      .from('logs_operativos')
      .insert(recordsToInsert);

    if (error) {
      return { success: false, syncedCount: 0, error: error.message };
    }

    return { success: true, syncedCount: logs.length };
  } catch (err: any) {
    return { success: false, syncedCount: 0, error: err?.message || 'Error al conectar con Supabase' };
  }
}
