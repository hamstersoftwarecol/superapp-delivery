<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class ResetPasswordNotification extends Notification
{
    public function __construct(#[\SensitiveParameter] public string $token) {}

    /**
     * @return list<string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $minutes = (int) config('auth.passwords.'.config('auth.defaults.passwords').'.expire');

        return (new MailMessage)
            ->subject('Recupera tu contraseña')
            ->greeting('Hola, '.$notifiable->name)
            ->line('Recibimos una solicitud para restablecer la contraseña de tu cuenta.')
            ->action('Crear una contraseña nueva', $this->resetUrl($notifiable))
            ->line("Este enlace vence en {$minutes} minutos y solo se puede usar una vez.")
            ->line('Si no fuiste tú, ignora este correo: tu contraseña no cambiará.')
            ->salutation('SuperApp Delivery');
    }

    /**
     * The reset form lives in the web panel, so it works for every role
     * without needing deep links in the mobile app.
     */
    private function resetUrl(object $notifiable): string
    {
        return rtrim((string) config('app.frontend_url'), '/').'/reset-password?'.http_build_query([
            'token' => $this->token,
            'email' => $notifiable->getEmailForPasswordReset(),
        ]);
    }
}
