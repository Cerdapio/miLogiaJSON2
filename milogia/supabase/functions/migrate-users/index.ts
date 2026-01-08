import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

// Contraseña temporal que se asignará a los usuarios migrados.
// DEBEN cambiarla en su primer inicio de sesión.
const TEMPORARY_PASSWORD = 'change-me-123';

serve(async (req) => {
  // Solo permitir el método POST para mayor seguridad
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    // 1. Crear un cliente de Supabase con privilegios de administrador (service_role)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 2. Obtener todos los usuarios de tu tabla que aún no han sido migrados (auth_uuid es null)
    const { data: usersToMigrate, error: fetchError } = await supabaseAdmin
      .from('catcUsuarios')
      .select('idUsuario, CorreoElectronico, Nombre')
      .is('auth_uuid', null);

    if (fetchError) throw fetchError;

    if (!usersToMigrate || usersToMigrate.length === 0) {
      return new Response(JSON.stringify({ message: 'No hay usuarios nuevos para migrar.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const migrationLog = [];

    // 3. Iterar sobre cada usuario y crear su cuenta en Supabase Auth
    for (const user of usersToMigrate) {
      const { CorreoElectronico, idUsuario, Nombre } = user;

      // Validar que el correo exista
      if (!CorreoElectronico) {
        migrationLog.push(`Usuario ID ${idUsuario} (${Nombre}) omitido: no tiene correo electrónico.`);
        continue;
      }

      // 4. Crear el usuario en el sistema de autenticación de Supabase
      const { data: authUser, error: signUpError } = await supabaseAdmin.auth.admin.createUser({
        email: CorreoElectronico,
        password: TEMPORARY_PASSWORD,
        email_confirm: true, // Marcar el email como confirmado para que puedan iniciar sesión
      });

      if (signUpError) {
        // Si el usuario ya existe en Auth, simplemente lo omitimos.
        if (signUpError.message.includes('already registered')) {
          migrationLog.push(`Usuario con correo ${CorreoElectronico} ya existía en Auth. Omitido.`);
          continue;
        }
        // Para otros errores, los registramos y continuamos
        migrationLog.push(`Error al crear usuario ${CorreoElectronico}: ${signUpError.message}`);
        continue;
      }

      // 5. Si la creación fue exitosa, actualizamos la tabla `catcUsuarios` con el nuevo auth_uuid
      const { error: updateError } = await supabaseAdmin
        .from('catcUsuarios')
        .update({ auth_uuid: authUser.user.id })
        .eq('idUsuario', idUsuario);

      if (updateError) {
        migrationLog.push(`Error al actualizar la tabla para ${CorreoElectronico}: ${updateError.message}`);
      } else {
        migrationLog.push(`Éxito: Usuario ${CorreoElectronico} migrado y vinculado.`);
      }
    }

    // 6. Devolver un resumen de lo que se hizo
    return new Response(JSON.stringify({
      message: 'Proceso de migración completado.',
      total_processed: usersToMigrate.length,
      log: migrationLog,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
