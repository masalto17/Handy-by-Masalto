import React, { useState } from 'react';
import { AuthScreen } from './components/AuthScreen';
import { HandyView } from './components/HandyView';
import { SqlMigrationModal } from './components/SqlMigrationModal';
import { LogsModal } from './components/LogsModal';
import { SimulatorControls } from './components/SimulatorControls';
import { EventDetails, UserRole } from './types';
import { LogServicio } from './services/logService';

export default function App() {
  const [activeEvent, setActiveEvent] = useState<EventDetails | null>(null);
  const [userName, setUserName] = useState<string>('');
  const [userRole, setUserRole] = useState<UserRole>('Producción');

  const [isSqlModalOpen, setIsSqlModalOpen] = useState(false);
  const [isLogsModalOpen, setIsLogsModalOpen] = useState(false);
  const [isSimulatedBusy, setIsSimulatedBusy] = useState(false);

  const handleAuthSuccess = (event: EventDetails, name: string, role: UserRole) => {
    setActiveEvent(event);
    setUserName(name);
    setUserRole(role);
  };

  const handleLogout = () => {
    setActiveEvent(null);
    setUserName('');
  };

  const handleSimulateIncomingVoice = (speakerName: string, role: string) => {
    setIsSimulatedBusy(true);
    setTimeout(() => {
      setIsSimulatedBusy(false);
    }, 4500);
  };

  const handleEmergencyAlert = () => {
    LogServicio.logEmergencyAlert('ALERTA S.O.S Activada por el operador desde panel de control');
    setIsLogsModalOpen(true);
  };

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 flex flex-col font-sans">
      
      {!activeEvent ? (
        /* SINGLE SCREEN LOGIN FLOW */
        <AuthScreen
          onSuccess={handleAuthSuccess}
          onOpenSqlModal={() => setIsSqlModalOpen(true)}
        />
      ) : (
        /* MAIN PTT HANDY VIEW */
        <div className="flex-1 flex flex-col justify-between">
          <HandyView
            event={activeEvent}
            userName={userName}
            userRole={userRole}
            onLogout={handleLogout}
            onOpenSqlModal={() => setIsSqlModalOpen(true)}
            onOpenLogsModal={() => setIsLogsModalOpen(true)}
            isSimulatedBusy={isSimulatedBusy}
          />

          {/* Floating Testing / Simulator Drawer Bar at Bottom */}
          <div className="p-3 bg-zinc-950 border-t border-zinc-800 max-w-lg mx-auto w-full">
            <SimulatorControls
              isBusy={isSimulatedBusy}
              onToggleBusy={() => setIsSimulatedBusy(!isSimulatedBusy)}
              onSimulateIncomingVoice={handleSimulateIncomingVoice}
              onEmergencyAlert={handleEmergencyAlert}
            />
          </div>
        </div>
      )}

      {/* SQL & RLS Migration Modal */}
      <SqlMigrationModal
        isOpen={isSqlModalOpen}
        onClose={() => setIsSqlModalOpen(false)}
      />

      {/* Operational Logs Inspector Modal */}
      <LogsModal
        isOpen={isLogsModalOpen}
        onClose={() => setIsLogsModalOpen(false)}
      />
    </div>
  );
}
