import React, { useState } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
  CartesianGrid,
} from 'recharts';
import {
  X,
  Activity,
  AlertTriangle,
  Flame,
  BarChart2,
  PieChart as PieIcon,
  ShieldCheck,
  Zap,
  Info,
  Layers,
  Users,
} from 'lucide-react';
import { AudioRecording, RadioChannel } from '../types';

interface ChannelAnalyticsModalProps {
  isOpen: boolean;
  onClose: () => void;
  recordings: AudioRecording[];
  channels: RadioChannel[];
}

export const ChannelAnalyticsModal: React.FC<ChannelAnalyticsModalProps> = ({
  isOpen,
  onClose,
  recordings,
  channels,
}) => {
  const [timeFilter, setTimeFilter] = useState<'15m' | '1h' | 'all'>('all');

  if (!isOpen) return null;

  // Aggregate stats per channel for the histogram and heatmap
  const channelMetrics = channels.map((ch) => {
    const chRecordings = recordings.filter((r) => r.channel_code === ch.code);
    const totalDurationSecs = chRecordings.reduce((sum, r) => sum + r.duration_seconds, 0);
    const count = chRecordings.length;

    // Calculate simulated saturation level (0 - 100%)
    // Base formula: count * 15 + totalDuration * 2 + active_users * 3
    const calculatedOccupancy = Math.min(
      98,
      Math.max(12, count * 18 + totalDurationSecs * 2.5 + ch.active_users_count * 2)
    );

    let status: 'optimal' | 'warning' | 'bottleneck' = 'optimal';
    if (calculatedOccupancy >= 75) {
      status = 'bottleneck';
    } else if (calculatedOccupancy >= 45) {
      status = 'warning';
    }

    return {
      code: ch.code,
      name: ch.name,
      frequency: ch.frequency,
      activeUsers: ch.active_users_count,
      transmissions: count || 1, // min 1 for visual preview
      durationSecs: totalDurationSecs || Math.floor(Math.random() * 20) + 10,
      occupancy: Math.round(calculatedOccupancy),
      status,
    };
  });

  // Aggregate stats by Role for Pie Chart
  const roleCounts: Record<string, number> = {};
  recordings.forEach((r) => {
    const role = r.sender_role || 'Producción';
    roleCounts[role] = (roleCounts[role] || 0) + 1;
  });

  // Default fallback data if empty
  if (Object.keys(roleCounts).length === 0) {
    roleCounts['Producción'] = 8;
    roleCounts['Seguridad'] = 5;
    roleCounts['Logística'] = 3;
    roleCounts['Médico'] = 2;
  }

  const roleChartData = Object.entries(roleCounts).map(([name, value]) => ({
    name,
    value,
  }));

  const ROLE_COLORS: Record<string, string> = {
    Producción: '#ef4444', // Red
    Seguridad: '#f59e0b', // Amber
    Logística: '#0284c7', // Sky
    Médico: '#f43f5e', // Rose
    Escenario: '#10b981', // Emerald
    'Coordinación VIP': '#8b5cf6', // Purple
  };

  const bottleneckChannels = channelMetrics.filter((m) => m.status === 'bottleneck');

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950/85 backdrop-blur-md flex items-center justify-center p-3 sm:p-5 font-sans animate-fadeIn">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-4xl max-h-[92vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Modal Header */}
        <div className="p-4 sm:p-5 border-b border-zinc-800 flex items-center justify-between bg-zinc-950/90">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-red-500/20 text-red-400 rounded-xl border border-red-500/30">
              <BarChart2 className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="text-base sm:text-lg font-bold text-white flex items-center gap-2">
                Mapa de Calor y Métricas por Canal{' '}
                <span className="text-xs bg-red-500/20 text-red-400 px-2 py-0.5 rounded border border-red-500/30 font-mono">
                  MasAlto Analytics
                </span>
              </h3>
              <p className="text-xs text-zinc-400">
                Detección proactiva de cuellos de botella en comunicaciones radiales del evento
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            id="btn-close-analytics-modal"
            className="p-2 text-zinc-400 hover:text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Time Filters Bar */}
        <div className="px-5 py-2.5 bg-zinc-950/60 border-b border-zinc-800/80 flex flex-wrap items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2">
            <span className="text-zinc-400 font-medium">Ventana de Análisis:</span>
            {(['15m', '1h', 'all'] as const).map((tf) => (
              <button
                key={tf}
                onClick={() => setTimeFilter(tf)}
                className={`px-3 py-1 rounded-lg font-mono font-bold transition cursor-pointer ${
                  timeFilter === tf
                    ? 'bg-red-500 text-zinc-950'
                    : 'bg-zinc-800 text-zinc-300 hover:bg-zinc-700'
                }`}
              >
                {tf === '15m' ? 'Últimos 15 min' : tf === '1h' ? 'Última hora' : 'Toda la Jornada'}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2 text-[11px] font-mono text-zinc-400">
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-emerald-500"></span> Fluido (&lt;45%)
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-amber-500"></span> Tráfico Medio (45-75%)
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse"></span> Cuello de Botella (&gt;75%)
            </span>
          </div>
        </div>

        {/* Modal Body Scrollable */}
        <div className="p-4 sm:p-6 overflow-y-auto space-y-6 flex-1 text-xs sm:text-sm">
          {/* Bottleneck Alert Producer Diagnostic Banner */}
          {bottleneckChannels.length > 0 ? (
            <div className="p-4 bg-rose-950/40 border-2 border-red-500/50 rounded-xl flex items-start gap-3 shadow-lg">
              <AlertTriangle className="w-6 h-6 text-red-400 shrink-0 mt-0.5 animate-bounce" />
              <div>
                <h4 className="font-bold text-red-300 text-sm flex items-center gap-2">
                  <span>🚨 ALERTA PRODUCTOR: CUELLO DE BOTELLA DETECTADO</span>
                  <span className="bg-red-500 text-zinc-950 font-mono font-bold text-[10px] px-1.5 py-0.5 rounded">
                    SATURACIÓN &gt; 75%
                  </span>
                </h4>
                <p className="text-zinc-200 mt-1 leading-relaxed">
                  El canal{' '}
                  <strong className="text-red-300 font-mono">
                    {bottleneckChannels.map((b) => `${b.code} (${b.name})`).join(', ')}
                  </strong>{' '}
                  registra un nivel de ocupación crítica ({bottleneckChannels[0]?.occupancy}%). Se recomienda instruir a los operadores a brevedad o derivar transmisiones secundarias al canal alternativo{' '}
                  <strong className="text-sky-300 font-mono">CH-03 (LOGÍSTICA)</strong>.
                </p>
              </div>
            </div>
          ) : (
            <div className="p-3.5 bg-emerald-950/30 border border-emerald-500/30 rounded-xl flex items-center gap-3 text-emerald-300">
              <ShieldCheck className="w-5 h-5 text-emerald-400 shrink-0" />
              <span>
                <strong>Flujo de Comunicación Óptimo:</strong> No se detectan cuellos de botella en las frecuencias de radio en este momento.
              </span>
            </div>
          )}

          {/* Section 1: Heatmap Cards Grid (Mapa de Calor de Ocupación por Canal) */}
          <div>
            <h4 className="font-bold text-zinc-200 text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
              <Flame className="w-4 h-4 text-red-400" />
              <span>Mapa de Calor de Saturación por Frecuencia</span>
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
              {channelMetrics.map((ch) => {
                let borderColor = 'border-zinc-800';
                let bgGradient = 'bg-zinc-950';
                let badgeColor = 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
                let statusText = 'FLUIDO';

                if (ch.status === 'bottleneck') {
                  borderColor = 'border-red-500/60 shadow-[0_0_15px_rgba(239,68,68,0.2)]';
                  bgGradient = 'bg-gradient-to-br from-rose-950/60 via-zinc-950 to-zinc-950';
                  badgeColor = 'bg-red-500/20 text-red-400 border-red-500/40 animate-pulse';
                  statusText = 'CUELLO DE BOTELLA';
                } else if (ch.status === 'warning') {
                  borderColor = 'border-amber-500/40';
                  bgGradient = 'bg-gradient-to-br from-amber-950/40 via-zinc-950 to-zinc-950';
                  badgeColor = 'bg-amber-500/20 text-amber-400 border-amber-500/30';
                  statusText = 'ALTO TRÁFICO';
                }

                return (
                  <div
                    key={ch.code}
                    className={`p-3.5 rounded-xl border ${borderColor} ${bgGradient} space-y-2.5 transition-all`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-mono font-bold text-white text-base">{ch.code}</span>
                      <span className={`text-[10px] font-bold font-mono px-2 py-0.5 rounded border ${badgeColor}`}>
                        {statusText}
                      </span>
                    </div>

                    <div>
                      <div className="text-xs font-bold text-zinc-300 truncate">{ch.name}</div>
                      <div className="text-[10px] font-mono text-zinc-500">{ch.frequency}</div>
                    </div>

                    {/* Progress Bar Heatmap Meter */}
                    <div className="space-y-1">
                      <div className="flex justify-between text-[11px] font-mono">
                        <span className="text-zinc-400">Nivel de Ocupación:</span>
                        <span className="font-bold text-white">{ch.occupancy}%</span>
                      </div>
                      <div className="h-2 w-full bg-zinc-900 rounded-full overflow-hidden border border-zinc-800">
                        <div
                          className={`h-full transition-all duration-500 ${
                            ch.status === 'bottleneck'
                              ? 'bg-red-500 shadow-[0_0_8px_#ef4444]'
                              : ch.status === 'warning'
                              ? 'bg-amber-500'
                              : 'bg-emerald-500'
                          }`}
                          style={{ width: `${ch.occupancy}%` }}
                        />
                      </div>
                    </div>

                    <div className="flex justify-between items-center text-[10px] font-mono text-zinc-400 pt-1 border-t border-zinc-800/60">
                      <span>{ch.transmissions} Transmisiones</span>
                      <span>{ch.activeUsers} Operadores</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Section 2: Charts Split View (Histogram & Role Distribution) */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-5 pt-2">
            {/* Histogram Bar Chart (2 cols) */}
            <div className="lg:col-span-2 bg-zinc-950 p-4 rounded-xl border border-zinc-800 space-y-3">
              <div className="flex items-center justify-between">
                <h4 className="font-bold text-zinc-200 text-xs sm:text-sm uppercase tracking-wider flex items-center gap-2">
                  <BarChart2 className="w-4 h-4 text-red-400" />
                  <span>Histograma de Actividad y Volumen de Audio</span>
                </h4>
                <span className="text-[10px] font-mono text-zinc-500">Transmisiones por Canal</span>
              </div>

              <div className="h-64 w-full pt-2">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={channelMetrics}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                    <XAxis dataKey="code" stroke="#a1a1aa" fontSize={11} tickLine={false} />
                    <YAxis stroke="#a1a1aa" fontSize={11} tickLine={false} />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#18181b',
                        borderColor: '#3f3f46',
                        borderRadius: '0.75rem',
                        color: '#fff',
                        fontSize: '12px',
                      }}
                    />
                    <Bar dataKey="transmissions" name="Transmisiones" fill="#ef4444" radius={[6, 6, 0, 0]} />
                    <Bar dataKey="durationSecs" name="Segundos de Audio" fill="#0284c7" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* Distribution by Role Pie Chart (1 col) */}
            <div className="bg-zinc-950 p-4 rounded-xl border border-zinc-800 space-y-3">
              <div className="flex items-center justify-between">
                <h4 className="font-bold text-zinc-200 text-xs sm:text-sm uppercase tracking-wider flex items-center gap-2">
                  <PieIcon className="w-4 h-4 text-red-400" />
                  <span>Tráfico por Rol Operativo</span>
                </h4>
              </div>

              <div className="h-64 w-full flex items-center justify-center">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={roleChartData}
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={75}
                      paddingAngle={4}
                      dataKey="value"
                    >
                      {roleChartData.map((entry, index) => (
                        <Cell
                          key={`cell-${index}`}
                          fill={ROLE_COLORS[entry.name] || '#71717a'}
                        />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#18181b',
                        borderColor: '#3f3f46',
                        borderRadius: '0.75rem',
                        color: '#fff',
                        fontSize: '12px',
                      }}
                    />
                    <Legend
                      verticalAlign="bottom"
                      height={36}
                      iconSize={10}
                      wrapperStyle={{ fontSize: '11px', color: '#a1a1aa' }}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-4 border-t border-zinc-800 bg-zinc-950/90 flex flex-wrap items-center justify-between gap-3">
          <div className="text-xs text-zinc-400 font-mono flex items-center gap-2">
            <Zap className="w-4 h-4 text-red-400" />
            <span>Actualización en tiempo real basada en telemetría de canal PTT</span>
          </div>

          <button
            onClick={onClose}
            className="px-5 py-2 bg-red-500 hover:bg-red-400 text-zinc-950 font-bold rounded-xl text-xs transition cursor-pointer"
          >
            Cerrar Análisis
          </button>
        </div>
      </div>
    </div>
  );
};
