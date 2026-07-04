import React, { useState, useEffect } from 'react';
import { LogServicio } from '../services/logService';
import { OperationalLog } from '../types';
import { 
  Activity, 
  X, 
  RefreshCw, 
  Send, 
  CheckCircle2, 
  Clock, 
  WifiOff, 
  AlertTriangle, 
  Radio, 
  Trash2,
  ListFilter
} from 'lucide-react';

interface LogsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const LogsModal: React.FC<LogsModalProps> = ({ isOpen, onClose }) => {
  const [pendingLogs, setPendingLogs] = useState<OperationalLog[]>([]);
  const [syncedLogs, setSyncedLogs] = useState<OperationalLog[]>([]);
  const [filterType, setFilterType] = useState<string>('ALL');
  const [isFlushing, setIsFlushing] = useState(false);
  const [flushStatus, setFlushStatus] = useState<string | null>(null);

  useEffect(() => {
    if (!isOpen) return;

    const updateLogs = () => {
      setPendingLogs(LogServicio.getPendingQueue());
      setSyncedLogs(LogServicio.getSyncedHistory());
    };

    updateLogs();
    const unsubscribe = LogServicio.subscribe(() => {
      updateLogs();
    });

    return () => unsubscribe();
  }, [isOpen]);

  if (!isOpen) return null;

  const handleFlush = async () => {
    setIsFlushing(true);
    setFlushStatus(null);
    const res = await LogServicio.flushBatch();
    setIsFlushing(false);

    if (res.success) {
      setFlushStatus(`✓ Se enviaron ${res.count} registros a la tabla logs_operativos.`);
    } else {
      setFlushStatus(`⚠️ Error: ${res.error || 'No se pudo sincronizar el lote.'}`);
    }

    setTimeout(() => setFlushStatus(null), 4000);
  };

  const allLogs = [...pendingLogs, ...syncedLogs].sort(
    (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
  );

  const filteredLogs = allLogs.filter(log => {
    if (filterType === 'ALL') return true;
    return log.event_type === filterType;
  });

  const getLogIcon = (type: string) => {
    switch (type) {
      case 'CHANNEL_CHANGE':
        return <Radio className="w-4 h-4 text-sky-400" />;
      case 'CONNECTION_FAILURE':
        return <WifiOff className="w-4 h-4 text-rose-400 animate-pulse" />;
      case 'RECONNECT_SUCCESS':
        return <CheckCircle2 className="w-4 h-4 text-red-400" />;
      case 'EMERGENCY_ALERT':
        return <AlertTriangle className="w-4 h-4 text-amber-400 animate-bounce" />;
      case 'PTT_START':
      case 'PTT_END':
        return <Activity className="w-4 h-4 text-red-400" />;
      default:
        return <Clock className="w-4 h-4 text-slate-400" />;
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950/80 backdrop-blur-sm flex items-center justify-center p-4 font-sans">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-3xl max-h-[85vh] flex flex-col shadow-2xl overflow-hidden">
        
        {/* Header */}
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between bg-zinc-900/90">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
              <Activity className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                Logs Operativos <span className="text-xs bg-zinc-800 text-red-400 px-2 py-0.5 rounded border border-zinc-700">LogServicio</span>
              </h3>
              <p className="text-xs text-zinc-400">Captura local en lote y sincronización con Supabase</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Queue Status Banner */}
        <div className="p-4 bg-zinc-950 border-b border-zinc-800 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-4 text-xs">
            <div className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-400 animate-ping" />
              <span className="text-zinc-300">
                Lote pendiente local: <strong className="text-amber-400 font-mono text-sm">{pendingLogs.length}</strong>
              </span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-3.5 h-3.5 text-red-400" />
              <span className="text-zinc-300">
                Sincronizados en Supabase: <strong className="text-red-400 font-mono text-sm">{syncedLogs.length}</strong>
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => LogServicio.clearLogs()}
              className="px-2.5 py-1.5 text-zinc-400 hover:text-rose-400 bg-zinc-900 hover:bg-zinc-800 rounded-lg text-xs border border-zinc-800 transition flex items-center gap-1 cursor-pointer"
            >
              <Trash2 className="w-3.5 h-3.5" /> Limpiar
            </button>
            <button
              onClick={handleFlush}
              disabled={isFlushing || pendingLogs.length === 0}
              id="btn-flush-logs-batch"
              className="px-3.5 py-1.5 bg-red-500 hover:bg-red-400 disabled:bg-zinc-800 disabled:text-zinc-500 text-zinc-950 font-bold text-xs rounded-lg transition flex items-center gap-1.5 shadow cursor-pointer disabled:cursor-not-allowed"
            >
              {isFlushing ? (
                <>
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  <span>Enviando...</span>
                </>
              ) : (
                <>
                  <Send className="w-3.5 h-3.5" />
                  <span>Enviar Lote Ahora ({pendingLogs.length})</span>
                </>
              )}
            </button>
          </div>
        </div>

        {flushStatus && (
          <div className="px-5 py-2.5 bg-rose-950/40 border-b border-rose-500/30 text-red-300 text-xs font-mono">
            {flushStatus}
          </div>
        )}

        {/* Filters */}
        <div className="px-5 py-2.5 bg-zinc-950/50 border-b border-zinc-800 flex items-center gap-2 overflow-x-auto">
          <ListFilter className="w-3.5 h-3.5 text-zinc-400 shrink-0" />
          {[
            { id: 'ALL', label: 'Todos' },
            { id: 'CHANNEL_CHANGE', label: 'Cambio Canal' },
            { id: 'CONNECTION_FAILURE', label: 'Fallo Conexión' },
            { id: 'PTT_START', label: 'Transmisión PTT' },
            { id: 'EMERGENCY_ALERT', label: 'S.O.S' },
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setFilterType(f.id)}
              className={`px-2.5 py-1 text-[11px] rounded-md font-medium transition whitespace-nowrap cursor-pointer ${
                filterType === f.id
                  ? 'bg-red-500/20 text-red-300 border border-red-500/40'
                  : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* Logs List */}
        <div className="p-4 overflow-y-auto flex-1 space-y-2">
          {filteredLogs.length === 0 ? (
            <div className="text-center py-12 text-zinc-500 text-xs">
              No hay eventos capturados en esta categoría.
            </div>
          ) : (
            filteredLogs.map(log => (
              <div
                key={log.id}
                className={`p-3 rounded-xl border transition flex items-start justify-between gap-3 ${
                  log.synced_to_supabase
                    ? 'bg-zinc-950/60 border-zinc-800'
                    : 'bg-amber-950/20 border-amber-500/30 shadow-sm'
                }`}
              >
                <div className="flex items-start gap-2.5">
                  <div className="p-1.5 rounded-lg bg-zinc-900 border border-zinc-800 mt-0.5">
                    {getLogIcon(log.event_type)}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-xs font-bold text-zinc-200">
                        {log.event_type}
                      </span>
                      <span className="text-[10px] bg-zinc-800 text-zinc-400 px-1.5 py-0.5 rounded">
                        {log.channel_id}
                      </span>
                      <span className="text-[10px] text-zinc-400">
                        {log.user_name} ({log.user_role})
                      </span>
                    </div>

                    <div className="text-xs text-zinc-400 font-mono mt-1 bg-zinc-900/80 p-1.5 rounded border border-zinc-800/50">
                      {JSON.stringify(log.details)}
                    </div>
                  </div>
                </div>

                <div className="text-right shrink-0">
                  <div className="text-[10px] text-zinc-400 font-mono">
                    {new Date(log.timestamp).toLocaleTimeString('es-AR')}
                  </div>
                  <span
                    className={`inline-block text-[9px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded mt-1 ${
                      log.synced_to_supabase
                        ? 'bg-red-500/20 text-red-400'
                        : 'bg-amber-500/20 text-amber-400'
                    }`}
                  >
                    {log.synced_to_supabase ? 'Enviado Supabase' : 'En Lote Local'}
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
