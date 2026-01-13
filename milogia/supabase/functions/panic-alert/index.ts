// panic-alert/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSign } from "node:crypto"
import { Buffer } from "node:buffer"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID')
const FCM_CLIENT_EMAIL = Deno.env.get('FCM_CLIENT_EMAIL')
const FCM_PRIVATE_KEY_RAW = Deno.env.get('FCM_PRIVATE_KEY')

async function getAccessToken() {
  if (!FCM_PRIVATE_KEY_RAW || !FCM_CLIENT_EMAIL) {
    throw new Error('Faltan configuraciones de FCM (Email o Private Key)')
  }
  const privateKey = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, '\n').trim()
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: FCM_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };
  const b64Header = Buffer.from(JSON.stringify(header)).toString("base64url");
  const b64Claim = Buffer.from(JSON.stringify(claim)).toString("base64url");
  const signatureInput = `${b64Header}.${b64Claim}`;
  const sign = createSign("RSA-SHA256");
  sign.update(signatureInput);
  const signature = sign.sign(privateKey, "base64url");
  const jwt = `${signatureInput}.${signature}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Error obteniendo token: ${JSON.stringify(data)}`);
  return data.access_token;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload = await req.json()
    console.log('Full Panic Alert Payload:', JSON.stringify(payload));
    
    const { 
        sender_id,
        sender_name, 
        sender_phone, 
        type, 
        assistance_details, 
        lat, 
        lon, 
        radius_km = 10 
    } = payload

    console.log(`Global Alert Triggered: ${type} from ${sender_name} (ID: ${sender_id}) at ${lat},${lon}`);

    // 1. Buscar usuarios cercanos vía RPC (Sin filtro de Gran Logia)
    const { data: recipients, error: dbError } = await supabaseClient
      .rpc('get_users_in_radius', {
        p_lat: lat,
        p_lon: lon,
        p_radius_meters: radius_km * 1000
      })

    if (dbError) throw dbError

    if (!recipients || recipients.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No recipients found in range' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Filtrar al remitente para que no se notifique a sí mismo
    const filteredRecipients = recipients.filter((r: any) => {
        // El RPC devuelve id_usuario. 
        const rid = String(r.id_usuario || r.idUsuario || r.user_id);
        const sid = sender_id ? String(sender_id) : null;
        
        // Si no tenemos SID, intentamos no auto-notificar por nombre/teléfono como último recurso
        if (!sid) {
          // Si el nombre y teléfono coinciden exactamente, es probable que sea el mismo usuario
          if (r.Nombre === sender_name || r.Telefono === sender_phone) return false;
          return true; 
        }
        
        return rid !== sid;
    });

    console.log(`Recipients to notify (${filteredRecipients.length}): ${filteredRecipients.map((r: any) => `ID: ${r.id_usuario}`).join(', ')}`);

    let tokens = filteredRecipients.map((r: any) => r.fcm_token).filter((t: string) => t)
    tokens = [...new Set(tokens)];

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No FCM tokens found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const isPanic = type === 'panic';
    // No usamos title/body de notificación para que no sea silenciada por el SO
    // Toda la información irá en el objeto 'data'
    
    const accessToken = await getAccessToken()

    let notifiedCount = 0;
    for (const token of tokens) {
      try {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json', 
            'Authorization': `Bearer ${accessToken}` 
          },
          body: JSON.stringify({
            message: {
              token: token,
              // IMPORTANTE: SIN campo "notification" para bypass de modo silencio
              data: { 
                type: 'PANIC_ALERT', 
                alert_type: type, // 'panic' or 'assistance'
                sender_name: sender_name,
                sender_phone: sender_phone,
                sender_grade: payload.sender_grade || '',
                sender_lodge: payload.sender_lodge || '',
                sender_gran_logia: payload.sender_gran_logia || '',
                sender_lat: String(lat),
                sender_lon: String(lon),
                details: assistance_details || '',
                severity: isPanic ? 'high' : 'medium'
              },
              android: {
                priority: 'high',
                ttl: '0s'
              }
            }
          })
        });
        if (res.ok) notifiedCount++;
      } catch (e: any) {
        console.error(`Error sending to token: ${e.message}`);
      }
    }

    return new Response(JSON.stringify({ 
        success: true, 
        notified: notifiedCount,
        message: `Alerta enviada a ${notifiedCount} hermanos cercanos.` 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    console.error('Panic Alert Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
