<?php

namespace App\Console\Commands;

use App\Enums\AccountStatus;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

#[Signature('admin:create {email : Correo del administrador} {--name= : Nombre (por defecto, la parte local del correo)}')]
#[Description('Crea una cuenta de administrador. La contraseña se pide de forma oculta.')]
class CreateAdmin extends Command
{
    public function handle(): int
    {
        $email = (string) $this->argument('email');
        $name = (string) ($this->option('name') ?: strstr($email, '@', true));

        $validator = Validator::make(['email' => $email, 'name' => $name], [
            'email' => ['required', 'email', 'unique:users,email'],
            'name' => ['required', 'string', 'max:255'],
        ]);

        if ($validator->fails()) {
            $this->error($validator->errors()->first());

            return self::FAILURE;
        }

        $password = (string) $this->secret('Contraseña (mínimo 8 caracteres)');

        $passwordValidator = Validator::make(['password' => $password], ['password' => ['required', Password::min(8)]]);

        if ($passwordValidator->fails()) {
            $this->error($passwordValidator->errors()->first());

            return self::FAILURE;
        }

        if ($password !== (string) $this->secret('Repite la contraseña')) {
            $this->error('Las contraseñas no coinciden.');

            return self::FAILURE;
        }

        (new User(['name' => $name, 'email' => $email, 'password' => $password]))
            ->forceFill(['role' => UserRole::Admin, 'status' => AccountStatus::Approved])
            ->save();

        $this->info("Administrador {$email} creado.");

        return self::SUCCESS;
    }
}
