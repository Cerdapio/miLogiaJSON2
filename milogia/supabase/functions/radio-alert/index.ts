import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createSign } from "node:crypto"
import { Buffer } from "node:buffer"

// --- CONFIGURACIÓN ---
const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID')
const FCM_CLIENT_EMAIL = Deno.env.get('FCM_CLIENT_EMAIL')
const FCM_PRIVATE_KEY_RAW = Deno.env.get('FCM_PRIVATE_KEY')

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

// Función para obtener el Access Token de Google (Manual JWT signing)
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
  try {
    const { idradio } = await req.json()
    console.log(`--- Iniciando Función radio-alert para idradio: ${idradio || 'TODOS (CRON)'} ---`)
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const accessToken = await getAccessToken()

    let radiosToProcess = []

    if (idradio) {
      // 1. Notificación Inmediata
      const { data, error } = await supabase.from('radios').select('*').eq('idradio', idradio).single()
      if (error || !data) throw new Error(`Radio ${idradio} no encontrado`)
      radiosToProcess = [data]
    } else {
      // 2. Notificación Periódica (CRON) + Recordatorio de Vencimiento hoy
      const todayDate = new Date();
      const todayStr = todayDate.toISOString().split('T')[0]; // YYYY-MM-DD

      const { data, error } = await supabase
        .from('radios')
        .select('*')
        .eq('is_active', true)
        .or(`periodicity.neq.once,valid_until.eq.${todayStr}`) // Traemos candidatos

      if (error) throw error
      
      const candidates = data || [];
      
      // Filtrar según periodicidad exacta
      radiosToProcess = candidates.filter(r => {
        // A. Siempre incluir si vence hoy (es recordatorio final)
        if (r.valid_until && r.valid_until.startsWith(todayStr)) return true;

        // B. Filtrar por periodicidad
        if (r.periodicity === 'once') return false; // Ya fue enviado al crearse (o venció hoy y entró por A)
        if (r.periodicity === 'daily') return true;

        const created = new Date(r.created_at);
        // Resetear horas para comparar fechas calendario
        const createdMidnight = new Date(created.getFullYear(), created.getMonth(), created.getDate());
        const todayMidnight = new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate());
        
        const diffTime = Math.abs(todayMidnight.getTime() - createdMidnight.getTime());
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 

        if (r.periodicity === 'weekly') {
          return diffDays % 7 === 0;
        }
        
        if (r.periodicity === 'monthly') {
          return todayDate.getDate() === created.getDate();
        }

        return false;
      });
    }

    let totalNotifications = 0

    for (const radio of radiosToProcess) {
      console.log(`Procesando radio: ${radio.title} (${radio.target_audience})`)

      // Buscar destinatarios
      let recipients: string[] = []
      
      if (radio.target_audience === 'own_lodge') {
        // Paso 1: Obtener tokens directamente de catdUsuario (logia emisora)
        const { data: users, error: userError } = await supabase
          .from('catdUsuario')
          .select('fcm_token')
          .eq('iddLogia', radio.issuing_logia_id)
          .eq('Activo', true)
          .not('fcm_token', 'is', null) // Solo usuarios con token
        
        if (userError) {
          console.error('Error obteniendo usuarios de la logia:', userError)
        } else {
          recipients = users?.map((u: any) => u.fcm_token) || []
        }
      } else if (radio.target_audience === 'subordinate_lodges') {
        // Lógica para Gran Logia -> Logias Subordinadas
        const { data: logiasHijas, error: logiaError } = await supabase
          .from('catdLogia')
          .select('iddLogia')
          .eq('idGranLogia', radio.issuing_logia_id)
          .eq('Activo', true)
          
        if (logiaError) {
          console.error('Error buscando logias hijas:', logiaError)
        } else {
          const logiaIds = logiasHijas?.map((l: any) => l.iddLogia) || []
          
          if (logiaIds.length > 0) {
            // Obtener tokens de usuarios de esas logias
            const { data: users, error: userError } = await supabase
              .from('catdUsuario')
              .select('fcm_token')
              .in('iddLogia', logiaIds)
              .eq('Activo', true)
              .not('fcm_token', 'is', null)
            
            if (userError) {
              console.error('Error buscando usuarios de logias hijas:', userError)
            } else {
              recipients = users?.map((u: any) => u.fcm_token) || []
            }
          }
        }
      } else {
        // Todas las logias (Cuidado: esto puede ser muchos usuarios)
        // Tomamos tokens de catdUsuario de todos los activos
        const { data, error: allUsersError } = await supabase
          .from('catdUsuario')
          .select('fcm_token')
          .eq('Activo', true)
          .not('fcm_token', 'is', null)
          
        if (allUsersError) {
          console.error('Error obteniendo todos los usuarios:', allUsersError)
        } else {
          recipients = data?.map((r: any) => r.fcm_token) || []
        }
      }

      // Deduplicar tokens (importante si un usuario tiene múltiples perfiles con el mismo token)
      recipients = [...new Set(recipients)];

      // Enviar notificaciones
      const isExpirationDay = radio.valid_until && radio.valid_until.startsWith(new Date().toISOString().split('T')[0])
      const titlePrefix = isExpirationDay ? 'FINAL RECORDATORIO: ' : 'Radio: '
      const bodySuffix = isExpirationDay ? ' (Vence hoy)' : ''

      for (const token of recipients) {
        try {
          await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${accessToken}` },
            body: JSON.stringify({
              message: {
                token: token,
                notification: { 
                  title: `${titlePrefix}${radio.title}`, 
                  body: `${radio.description || 'Comunicado oficial'}${bodySuffix}` 
                },
                data: { 
                  type: 'radio_alert', 
                  idradio: String(radio.idradio),
                  url: radio.document_url || ''
                }
              }
            })
          })
          totalNotifications++
        } catch (e) {
          console.error(`Error enviando notificación:`, e)
        }
      }
    }

    return new Response(JSON.stringify({ message: "Éxito", total: totalNotifications }), { 
      headers: { "Content-Type": "application/json" } 
    })

  } catch (err) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
