class NotificationServiceClass {
  private permission: NotificationPermission = 'default';

  constructor() {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      this.permission = Notification.permission;
    }
  }

  public getPermissionStatus(): NotificationPermission {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      this.permission = Notification.permission;
    }
    return this.permission;
  }

  public async requestPermission(): Promise<NotificationPermission> {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      console.warn('[NotificationService] Notificaciones no soportadas en este navegador.');
      return 'denied';
    }

    try {
      const result = await Notification.requestPermission();
      this.permission = result;
      if (result === 'granted') {
        this.sendNotification('Notificaciones HANDY Activas', {
          body: 'Recibirás alertas operativas y transmisión de voz aunque la app esté en segundo plano.',
          tag: 'handy-welcome',
        });
      }
      return result;
    } catch (err) {
      console.error('[NotificationService] Error al solicitar permisos:', err);
      return 'denied';
    }
  }

  /**
   * Envía una notificación push si la app no tiene el foco o si es de alta prioridad.
   */
  public sendNotification(
    title: string,
    options: {
      body: string;
      icon?: string;
      tag?: string;
      requireInteraction?: boolean;
      priority?: 'normal' | 'high' | 'urgent';
    }
  ): boolean {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      return false;
    }

    if (this.getPermissionStatus() !== 'granted') {
      console.log('[NotificationService] Notificación omitida: permiso no otorgado.');
      return false;
    }

    const isBackground = document.hidden || !document.hasFocus();

    // If urgent (like EMERGENCY SOS), always notify, otherwise notify when in background
    if (options.priority === 'urgent' || isBackground) {
      try {
        const notif = new Notification(title, {
          body: options.body,
          tag: options.tag || `handy-notif-${Date.now()}`,
          requireInteraction: options.requireInteraction || options.priority === 'urgent',
          icon: '/favicon.ico',
        });

        // Trigger vibration pattern if supported
        if ('vibrate' in navigator) {
          if (options.priority === 'urgent') {
            navigator.vibrate([300, 100, 300, 100, 500]);
          } else {
            navigator.vibrate([150, 50, 150]);
          }
        }

        notif.onclick = () => {
          if (typeof window !== 'undefined') {
            window.focus();
            notif.close();
          }
        };

        return true;
      } catch (err) {
        console.warn('[NotificationService] Error al disparar notificación:', err);
        return false;
      }
    }

    return false;
  }

  public notifyEmergency(senderName: string, channelCode: string, reason: string) {
    this.sendNotification(`🚨 ALERTA S.O.S • CANAL ${channelCode}`, {
      body: `Emisor: ${senderName}\nDetalle: ${reason}`,
      tag: `emergency-${Date.now()}`,
      priority: 'urgent',
      requireInteraction: true,
    });
  }

  public notifyVoiceMessage(senderName: string, senderRole: string, channelCode: string, text: string) {
    this.sendNotification(`🎙️ Orden de Voz en ${channelCode}`, {
      body: `${senderName} (${senderRole}): "${text}"`,
      tag: `voice-${channelCode}`,
      priority: 'normal',
    });
  }

  public notifyNetworkIssue(reason: string) {
    this.sendNotification('⚠️ Pérdida de Conexión en Estadio', {
      body: `Atención: ${reason}. Guardando grabaciones en IndexedDB offline.`,
      tag: 'network-alert',
      priority: 'high',
    });
  }
}

export const notificationService = new NotificationServiceClass();
