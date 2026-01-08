import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const formData = await req.formData();
    const file = formData.get('file') as File;
    const logiaId = formData.get('logiaId') as string;
    const folder = formData.get('folder') as string ?? 'radios'; // 'radios' por defecto

    if (!file || !logiaId) {
      throw new Error('Falta el archivo o el ID de logia.');
    }

    const bucketName = 'radios_docs';
    // Mantenemos la estructura de carpetas pero permitimos cambiar la raíz (radios/ o payments/)
    const fileName = `${Date.now()}_${file.name}`;
    const filePath = `${folder}/${logiaId}/${fileName}`;

    // Subir usando el cliente admin para saltar RLS
    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(filePath, file, {
        cacheControl: '3600',
        upsert: false,
      });

    if (uploadError) throw uploadError;

    // Obtener la URL pública (ya que el bucket es público)
    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(filePath);

    // Devolvemos tanto la URL como el PATH para que la base de datos pueda guardarlos
    return new Response(JSON.stringify({ publicUrl, filePath }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
