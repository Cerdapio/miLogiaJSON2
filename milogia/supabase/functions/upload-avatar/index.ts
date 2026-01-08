import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req: Request) => {
  // Manejar la solicitud pre-vuelo (CORS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Crear un cliente de Supabase con privilegios de 'service_role'
    // Esto nos permite saltarnos las políticas de RLS para esta operación controlada.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Extraer los datos del cuerpo de la solicitud (el archivo y el idUsuario)
    const formData = await req.formData();
    const file = formData.get('avatar') as File;
    const userId = formData.get('userId') as string;

    if (!file || !userId) {
      throw new Error('Falta el archivo (avatar) o el ID de usuario (userId).');
    }

    const bucketName = 'profilePictures';
    const filePath = `${userId}.png`;

    // 3. Subir el nuevo archivo al Storage, sobrescribiendo si existe.
    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(filePath, file, {
        cacheControl: '3600',
        upsert: true, // Esto elimina la necesidad de borrar el archivo antiguo primero
      });

    if (uploadError) throw uploadError;

    // 4. Generar una URL firmada (Signed URL) en lugar de una pública.
    // Le damos una validez muy larga (ej. 10 años en segundos) para que no expire pronto.
    const tenYearsInSeconds = 10 * 365 * 24 * 60 * 60;
    const { data: signedUrlData, error: signedUrlError } = await supabaseAdmin.storage
      .from(bucketName)
      .createSignedUrl(filePath, tenYearsInSeconds);

    if (signedUrlError) throw signedUrlError;

    // La URL ya incluye un token de autorización, por lo que no necesita el "cache buster".
    const publicUrl = signedUrlData.signedUrl;

    // 5. Actualizar la URL de la foto en la tabla 'catcUsuarios'
    const { error: dbError } = await supabaseAdmin
      .from('catcUsuarios')
      .update({ Foto: publicUrl })
      .eq('idUsuario', userId);

    if (dbError) throw dbError;

    // 6. Devolver la URL actualizada al cliente
    return new Response(JSON.stringify({ avatarUrl: publicUrl }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    // Best practice: handle unknown error type
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    console.error(error); // Log the full error for debugging
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
