import { LogEventType, OperationalLog } from '../types';
import { sendLogsBatchToSupabase } from './supabaseClient';
import { indexedDbService } from './indexedDbService';
import { notificationService } from './notificationService';

const STORAGE_KEY = 'event_radio_pending_logs';
const SYNCED_STORAGE_KEY = 'event_radio_synced_logs';
const BATCH_FLUSH_INTERVAL = 8000; // 8 seconds
const MAX_BATCH_SIZE = 5;

type LogListener = (pendingCount: number, syncedCount: number, lastLog?: OperationalLog) => void;

class LogServicioClass {
  private pendingQueue: OperationalLog[] = [];
  private syncedHistory: OperationalLog[] = [];
  private listeners: Set<LogListener> = new Set();
  private flushTimer: any = null;
  private isFlushing = false;

  private currentUserId = 'usr-anonymous';
  private currentUserName = 'Operador';
  private currentUserRole = 'Producción';
  private currentEventId = 'evt-default';
  private currentChannelId = 'CH-01';

  constructor() {
    this.loadFromStorage();
    this.startAutoFlush();
  }

  public setContext(context: {
    userId?: string;
    userName?: string;
    userRole?: string;
    eventId?: string;
    channelId?: string;
  }) {
    if (context.userId) this.currentUserId = context.userId;
    if (context.userName) this.currentUserName = context.userName;
    if (context.userRole) this.currentUserRole = context.userRole;
    if (context.eventId) this.currentEventId = context.eventId;
    if (context.channelId) this.currentChannelId = context.channelId;
  }

  private loadFromStorage() {
    try {
      const rawPending = localStorage.getItem(STORAGE_KEY);
      if (rawPending) {
        this.pendingQueue = JSON.parse(rawPending);
      }
      const rawSynced = localStorage.getItem(SYNCED_STORAGE_KEY);
      if (rawSynced) {
        this.syncedHistory = JSON.parse(rawSynced);
      }
    } catch (err) {
      console.warn('Error loading logs from storage:', err);
      this.pendingQueue = [];
      this.syncedHistory = [];
    }
  }

  private saveToStorage() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.pendingQueue));
      localStorage.setItem(SYNCED_STORAGE_KEY, JSON.stringify(this.syncedHistory.slice(-50)));
    } catch (err) {
      console.warn('Error saving logs to storage:', err);
    }
  }

  private startAutoFlush() {
    if (this.flushTimer) clearInterval(this.flushTimer);
    this.flushTimer = setInterval(() => {
      if (this.pendingQueue.length > 0 && !this.isFlushing) {
        this.flushBatch();
      }
    }, BATCH_FLUSH_INTERVAL);
  }

  public subscribe(listener: LogListener) {
    this.listeners.add(listener);
    listener(this.pendingQueue.length, this.syncedHistory.length);
    return () => this.listeners.delete(listener);
  }

  private notifyListeners(lastLog?: OperationalLog) {
    this.listeners.forEach(cb => cb(this.pendingQueue.length, this.syncedHistory.length, lastLog));
  }

  /**
   * Captures an operational event into local storage and IndexedDB immediately.
   */
  public logEvent(eventType: LogEventType, details: Record<string, any> = {}) {
    const logItem: OperationalLog = {
      id: `log-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      event_id: this.currentEventId,
      user_id: this.currentUserId,
      user_name: this.currentUserName,
      user_role: this.currentUserRole,
      channel_id: this.currentChannelId,
      event_type: eventType,
      details,
      timestamp: new Date().toISOString(),
      synced_to_supabase: false,
    };

    this.pendingQueue.push(logItem);
    this.saveToStorage();
    
    // Save to IndexedDB persistence layer
    indexedDbService.saveLog(logItem);

    this.notifyListeners(logItem);

    console.log(`[LogServicio] Evento capturado en almacenamiento local e IndexedDB (${eventType}):`, details);

    // Trigger push notification if critical event
    if (eventType === 'EMERGENCY_ALERT') {
      notificationService.notifyEmergency(this.currentUserName, this.currentChannelId, details?.alert_reason || 'Alerta Crítica');
    } else if (eventType === 'CONNECTION_FAILURE') {
      notificationService.notifyNetworkIssue(details?.reason || 'Fallo de señal');
    }

    // Auto flush if batch size exceeded
    if (this.pendingQueue.length >= MAX_BATCH_SIZE) {
      this.flushBatch();
    }
  }

  // --- Specialized Helper Methods requested by specification ---

  /**
   * Captura de cambio de canal
   */
  public logChannelChange(fromChannel: string, toChannel: string) {
    this.currentChannelId = toChannel;
    this.logEvent('CHANNEL_CHANGE', {
      from_channel: fromChannel,
      to_channel: toChannel,
      timestamp_local: new Date().toLocaleTimeString('es-AR'),
    });
  }

  /**
   * Captura de fallo de conexión (LiveKit / WebRTC / Socket)
   */
  public logConnectionFailure(reason: string, details?: Record<string, any>) {
    this.logEvent('CONNECTION_FAILURE', {
      reason,
      network_type: navigator.onLine ? 'online_degraded' : 'offline',
      latency_ms: details?.latencyMs || null,
      error_message: details?.message || 'Pérdida de paquetes en servidor LiveKit',
      ...details
    });
  }

  /**
   * Captura de reconexión exitosa
   */
  public logReconnectSuccess(reconnectDurationMs?: number) {
    this.logEvent('RECONNECT_SUCCESS', {
      reconnect_duration_ms: reconnectDurationMs || 450,
      status: 'Restablecido',
    });
  }

  /**
   * Captura de transmisión PTT
   */
  public logPttStart() {
    this.logEvent('PTT_START', {
      action: 'press_talk',
    });
  }

  public logPttEnd(durationMs: number) {
    this.logEvent('PTT_END', {
      action: 'release_talk',
      duration_ms: durationMs,
    });
  }

  /**
   * Enviar alerta SOS de emergencia
   */
  public logEmergencyAlert(reason: string) {
    this.logEvent('EMERGENCY_ALERT', {
      alert_reason: reason,
      priority: 'CRITICAL',
    });
  }

  /**
   * Envía el lote actual de logs a Supabase.
   */
  public async flushBatch(): Promise<{ success: boolean; count: number; error?: string }> {
    if (this.pendingQueue.length === 0) {
      return { success: true, count: 0 };
    }

    if (this.isFlushing) {
      return { success: false, count: 0, error: 'Envío en curso...' };
    }

    this.isFlushing = true;
    const batchToSend = [...this.pendingQueue];

    try {
      const result = await sendLogsBatchToSupabase(batchToSend);

      if (result.success) {
        // Mark items as synced
        const syncedItems = batchToSend.map(item => ({
          ...item,
          synced_to_supabase: true,
        }));

        this.syncedHistory.unshift(...syncedItems);
        // Remove synced from pending
        this.pendingQueue = this.pendingQueue.filter(
          item => !batchToSend.some(b => b.id === item.id)
        );

        this.saveToStorage();
        this.notifyListeners();
        console.log(`[LogServicio] Lote de ${syncedItems.length} logs enviado con éxito a Supabase.`);
        this.isFlushing = false;
        return { success: true, count: syncedItems.length };
      } else {
        console.warn('[LogServicio] Error enviando lote a Supabase:', result.error);
        this.isFlushing = false;
        return { success: false, count: 0, error: result.error };
      }
    } catch (err: any) {
      console.error('[LogServicio] Excepción durante el envío de lote:', err);
      this.isFlushing = false;
      return { success: false, count: 0, error: err?.message || 'Error de red' };
    }
  }

  public getPendingQueue(): OperationalLog[] {
    return [...this.pendingQueue];
  }

  public getSyncedHistory(): OperationalLog[] {
    return [...this.syncedHistory];
  }

  public clearLogs() {
    this.pendingQueue = [];
    this.syncedHistory = [];
    localStorage.removeItem(STORAGE_KEY);
    localStorage.removeItem(SYNCED_STORAGE_KEY);
    this.notifyListeners();
  }
}

export const LogServicio = new LogServicioClass();
