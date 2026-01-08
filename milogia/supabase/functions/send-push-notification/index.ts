// supabase/functions/send-push-notification/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { google } from "https://esm.sh/googleapis";

// Clave de servicio de Firebase (guardada como secreto en Supabase)
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Inicializa el cliente de autenticación de Google
const jwtClient = new google.auth.JWT(
  JSON.parse(FIREBASE_SERVICE_ACCOUNT!).client_email,
  null,
  JSON.parse(FIREBASE_SERVICE_ACCOUNT!).private_key,
  ["https://www.googleapis.com/auth/firebase.messaging"],
  null
);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_id, title, body } = await req.json();
    if (!user_id || !title || !body) {
      throw new Error("Faltan parámetros: se requiere user_id, title y body.");
    }

    // Crea un cliente de Supabase para consultar la tabla de tokens
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Busca los tokens del usuario
    const { data: tokens, error: tokenError } = await supabaseAdmin
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id);

    if (tokenError) throw tokenError;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "El usuario no tiene dispositivos registrados." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Prepara y envía las notificaciones
    const registrationTokens = tokens.map(t => t.token);
    const accessToken = await jwtClient.getAccessToken();

    const fcmResponse = await fetch("https://fcm.googleapis.com/v1/projects/milogianotifications/messages:send", { // <-- REEMPLAZA 'MY-PROJECT-ID'
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken.token}`,
      },
      body: JSON.stringify({
        message: {
          tokens: registrationTokens,
          notification: { title, body },
          // Opcional: puedes añadir datos para manejar la notificación en la app
          data: { screen: 'home' } 
        },
      }),
    });

    if (!fcmResponse.ok) {
      const errorData = await fcmResponse.json();
      console.error("Error de FCM:", errorData);
      throw new Error("Error al enviar la notificación push.");
    }

    return new Response(JSON.stringify({ success: true, message: `Notificación enviada a ${registrationTokens.length} dispositivos.` }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
