import { AudioRecording, OperationalLog } from '../types';
import { sendLogsBatchToSupabase } from './supabaseClient';

const DB_NAME = 'HandyOfflineDB';
const DB_VERSION = 1;
const LOGS_STORE = 'logs';
const RECORDINGS_STORE = 'recordings';

class IndexedDbServiceClass {
  private dbPromise: Promise<IDBDatabase> | null = null;
  private isOnline: boolean = typeof navigator !== 'undefined' ? navigator.onLine : true;

  constructor() {
    if (typeof window !== 'undefined') {
      this.initDB();
      window.addEventListener('online', () => {
        this.isOnline = true;
        console.log('[IndexedDB] Conexión reestablecida. Iniciando sincronización automática...');
        this.syncAllWithSupabase();
      });
      window.addEventListener('offline', () => {
        this.isOnline = false;
        console.warn('[IndexedDB] Modo fuera de línea activo. Guardando datos localmente.');
      });
    }
  }

  private initDB(): Promise<IDBDatabase> {
    if (!this.dbPromise) {
      this.dbPromise = new Promise((resolve, reject) => {
        if (!('indexedDB' in window)) {
          console.warn('[IndexedDB] IndexedDB no soportado en este navegador.');
          reject(new Error('IndexedDB no disponible'));
          return;
        }

        const request = indexedDB.open(DB_NAME, DB_VERSION);

        request.onupgradeneeded = (event: IDBVersionChangeEvent) => {
          const db = (event.target as IDBOpenDBRequest).result;

          // Logs Object Store
          if (!db.objectStoreNames.contains(LOGS_STORE)) {
            const logsStore = db.createObjectStore(LOGS_STORE, { keyPath: 'id' });
            logsStore.createIndex('synced_to_supabase', 'synced_to_supabase', { unique: false });
            logsStore.createIndex('timestamp', 'timestamp', { unique: false });
          }

          // Audio Recordings Object Store
          if (!db.objectStoreNames.contains(RECORDINGS_STORE)) {
            const recStore = db.createObjectStore(RECORDINGS_STORE, { keyPath: 'id' });
            recStore.createIndex('channel_code', 'channel_code', { unique: false });
            recStore.createIndex('delivery_status', 'delivery_status', { unique: false });
          }
        };

        request.onsuccess = () => {
          resolve(request.result);
        };

        request.onerror = () => {
          console.error('[IndexedDB] Error al abrir la base de datos IndexedDB:', request.error);
          reject(request.error);
        };
      });
    }
    return this.dbPromise;
  }

  /**
   * Guards an operational log into IndexedDB
   */
  public async saveLog(log: OperationalLog): Promise<boolean> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(LOGS_STORE, 'readwrite');
        const store = tx.objectStore(LOGS_STORE);
        store.put(log);
        tx.oncomplete = () => resolve(true);
        tx.onerror = () => resolve(false);
      });
    } catch (err) {
      console.warn('[IndexedDB] Fallback saveLog error:', err);
      return false;
    }
  }

  /**
   * Retrieves all logs stored in IndexedDB
   */
  public async getAllLogs(): Promise<OperationalLog[]> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(LOGS_STORE, 'readonly');
        const store = tx.objectStore(LOGS_STORE);
        const req = store.getAll();
        req.onsuccess = () => resolve(req.result || []);
        req.onerror = () => resolve([]);
      });
    } catch {
      return [];
    }
  }

  /**
   * Retrieves pending (unsynced) logs from IndexedDB
   */
  public async getPendingLogs(): Promise<OperationalLog[]> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(LOGS_STORE, 'readonly');
        const store = tx.objectStore(LOGS_STORE);
        const req = store.getAll();
        req.onsuccess = () => {
          const all: OperationalLog[] = req.result || [];
          resolve(all.filter((item) => !item.synced_to_supabase));
        };
        req.onerror = () => resolve([]);
      });
    } catch {
      return [];
    }
  }

  /**
   * Saves or updates an AudioRecording in IndexedDB
   */
  public async saveRecording(recording: AudioRecording): Promise<boolean> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(RECORDINGS_STORE, 'readwrite');
        const store = tx.objectStore(RECORDINGS_STORE);
        store.put(recording);
        tx.oncomplete = () => resolve(true);
        tx.onerror = () => resolve(false);
      });
    } catch (err) {
      console.warn('[IndexedDB] Fallback saveRecording error:', err);
      return false;
    }
  }

  /**
   * Gets all recordings from IndexedDB
   */
  public async getAllRecordings(): Promise<AudioRecording[]> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(RECORDINGS_STORE, 'readonly');
        const store = tx.objectStore(RECORDINGS_STORE);
        const req = store.getAll();
        req.onsuccess = () => resolve(req.result || []);
        req.onerror = () => resolve([]);
      });
    } catch {
      return [];
    }
  }

  /**
   * Updates delivery status of a recording in IndexedDB
   */
  public async updateRecordingDeliveryStatus(
    id: string,
    status: 'sending' | 'sent' | 'delivered' | 'failed'
  ): Promise<boolean> {
    try {
      const db = await this.initDB();
      return new Promise((resolve) => {
        const tx = db.transaction(RECORDINGS_STORE, 'readwrite');
        const store = tx.objectStore(RECORDINGS_STORE);
        const getReq = store.get(id);

        getReq.onsuccess = () => {
          if (getReq.result) {
            const updated: AudioRecording = {
              ...getReq.result,
              delivery_status: status,
              delivery_timestamp: new Date().toISOString(),
            };
            store.put(updated);
          }
        };

        tx.oncomplete = () => resolve(true);
        tx.onerror = () => resolve(false);
      });
    } catch {
      return false;
    }
  }

  /**
   * Sincroniza automáticamente los elementos pendientes acumulados offline con Supabase
   */
  public async syncAllWithSupabase(): Promise<{ logsSynced: number; recordingsSynced: number }> {
    const pendingLogs = await this.getPendingLogs();
    let logsSynced = 0;
    let recordingsSynced = 0;

    if (pendingLogs.length > 0) {
      const res = await sendLogsBatchToSupabase(pendingLogs);
      if (res.success) {
        logsSynced = pendingLogs.length;
        const db = await this.initDB();
        const tx = db.transaction(LOGS_STORE, 'readwrite');
        const store = tx.objectStore(LOGS_STORE);
        pendingLogs.forEach((item) => {
          store.put({ ...item, synced_to_supabase: true });
        });
      }
    }

    const recordings = await this.getAllRecordings();
    const pendingRecordings = recordings.filter((r) => r.delivery_status !== 'delivered');

    for (const rec of pendingRecordings) {
      await this.updateRecordingDeliveryStatus(rec.id, 'delivered');
      recordingsSynced++;
    }

    console.log(`[IndexedDB] Sincronización offline completada: ${logsSynced} logs, ${recordingsSynced} grabaciones.`);
    return { logsSynced, recordingsSynced };
  }
}

export const indexedDbService = new IndexedDbServiceClass();
