export type UserRole = 
  | 'Seguridad'
  | 'Producción'
  | 'Logística'
  | 'Médico'
  | 'Escenario'
  | 'Coordinación VIP'
  | 'Comunicaciones';

export interface Participant {
  id: string;
  user_id: string;
  name: string;
  role: UserRole;
  event_id: string;
  channel_id: string;
  is_online: boolean;
  is_talking: boolean;
  last_active: string;
}

export interface EventDetails {
  id: string;
  name: string;
  venue: string;
  invite_code: string;
  date: string;
  channels_count: number;
}

export interface RadioChannel {
  id: string;
  code: string;
  name: string;
  frequency: string;
  description: string;
  active_users_count: number;
  color: string;
}

export type PttStatus = 'idle' | 'talking' | 'busy' | 'connecting';

export type LogEventType = 
  | 'CHANNEL_CHANGE'
  | 'PTT_START'
  | 'PTT_END'
  | 'CONNECTION_FAILURE'
  | 'RECONNECT_SUCCESS'
  | 'MIC_PERMISSION_GRANTED'
  | 'MIC_PERMISSION_DENIED'
  | 'EMERGENCY_ALERT'
  | 'INVITE_CODE_VALIDATED';

export interface OperationalLog {
  id: string;
  event_id: string;
  user_id: string;
  user_name: string;
  user_role: string;
  channel_id: string;
  event_type: LogEventType;
  details: Record<string, any>;
  timestamp: string;
  synced_to_supabase: boolean;
}

export interface SupabaseConfig {
  url: string;
  anonKey: string;
  isConnected: boolean;
}

export type DeliveryStatus = 'sending' | 'sent' | 'delivered' | 'failed';

export interface AudioRecording {
  id: string;
  event_id: string;
  channel_code: string;
  channel_name: string;
  sender_name: string;
  sender_role: UserRole | string;
  timestamp: string;
  duration_seconds: number;
  transcription: string;
  is_emergency?: boolean;
  audio_url?: string;
  delivery_status?: DeliveryStatus;
  delivery_timestamp?: string;
}

