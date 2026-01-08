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
    console.error('ERROR: Faltan secretos de FCM.', { 
      hasProjectId: !!FCM_PROJECT_ID,
      hasEmail: !!FCM_CLIENT_EMAIL, 
      hasKey: !!FCM_PRIVATE_KEY_RAW 
    })
    throw new Error('Faltan configuraciones de FCM (Email o Private Key)')
  }

  // Normalizar la llave PEM: reemplaza los \n literales por saltos de línea reales
  const privateKey = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, '\n').trim()
  
  if (!privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
     console.error('ERROR: La llave privada no tiene el formato PEM esperado.')
     throw new Error('Llave privada inválida')
  }

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
    console.log('--- Iniciando Función birthday-alert (Logia-wide) ---')
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // 1. Calcular fechas
    const today = new Date()
    const tomorrow = new Date()
    tomorrow.setDate(today.getDate() + 1)
    const formatMD = (d: Date) => `-${(d.getMonth()+1).toString().padStart(2,'0')}-${d.getDate().toString().padStart(2,'0')}`
    const matcherToday = formatMD(today)
    const matcherTomorrow = formatMD(tomorrow)
    
    console.log(`Buscando cumpleañeros para Hoy (${matcherToday}) y Mañana (${matcherTomorrow})...`)

    // 2. Obtener usuarios básicos para checar fechas (catcUsuarios) - SIN TOKEN
    const { data: allUsers, error: uError } = await supabase
      .from('catcUsuarios')
      .select('idUsuario, Nombre, FechaNacimiento')
      .not('FechaNacimiento', 'is', null)

    if (uError) throw uError

    // Filtrar los que cumplen años hoy o mañana
    const peopleHavingBirthday = (allUsers || []).filter((u: any) => {
      const bday = u.FechaNacimiento || ''
      return bday.endsWith(matcherToday) || bday.endsWith(matcherTomorrow)
    })

    if (peopleHavingBirthday.length === 0) {
      console.log('Nadie cumple años hoy ni mañana.')
      return new Response(JSON.stringify({ message: "Nadie cumple años" }), { status: 200, headers: { "Content-Type": "application/json" } })
    }

    // 3. Obtener el mapeo de Logias de catdUsuario (para saber a qué logia pertenece cada celebrante)
    // Solo nos interesan los usuarios que cumplen años
    const celebrantIds = peopleHavingBirthday.map((u: any) => u.idUsuario);
    
    const { data: celebrantLogias, error: lError } = await supabase
      .from('catdUsuario')
      .select('idUsuario, iddLogia')
      .in('idUsuario', celebrantIds)
      .eq('Activo', true)

    if (lError) throw lError

    // Mapa: idUsuario -> iddLogia
    const userLogiaMap = new Map();
    celebrantLogias?.forEach((m: any) => userLogiaMap.set(m.idUsuario, m.iddLogia));

    // 4. Obtener Access Token
    const accessToken = await getAccessToken()
    let notificationsSent = 0

    // 5. Procesar notificaciones
    for (const celebrante of peopleHavingBirthday) {
      const isToday = celebrante.FechaNacimiento.endsWith(matcherToday)
      const logiaId = userLogiaMap.get(celebrante.idUsuario)

      if (!logiaId) {
        console.log(`El usuario ${celebrante.Nombre} no tiene una Logia activa asignada. Saltando...`)
        continue
      }

      console.log(`Procesando cumpleaños de ${celebrante.Nombre} en Logia ${logiaId}...`)

      // --- CORRECCIÓN: Obtener tokens desde catdUsuario de esa Logia ---
      const { data: recipients, error: rError } = await supabase
        .from('catdUsuario')
        .select('fcm_token, idUsuario') // idUsuario para no notificarse a sí mismo (opcional)
        .eq('iddLogia', logiaId)
        .eq('Activo', true)
        .not('fcm_token', 'is', null)

      if (rError) {
        console.error('Error obteniendo destinatarios:', rError);
        continue;
      }

      // Filtrar tokens duplicados y evitar enviar al propio celebrante (opcional, pero recomendado)
      // Aunque a veces uno quiere recibir su propia felicitación para confirmar :P Démosle.
      const tokens = [...new Set(recipients?.map((r: any) => r.fcm_token) || [])];
      
      const title = isToday ? `¡Hoy es cumpleaños de ${celebrante.Nombre}!` : `Mañana cumple años ${celebrante.Nombre}`
      const body = isToday 
        ? `Celebramos una vuelta más al sol de nuestro Q.H. ${celebrante.Nombre}. ¡Felicidades!` 
        : `Mañana celebramos a nuestro Q.H. ${celebrante.Nombre}. ¡Prepárate!`;

      for (const token of tokens) {
        try {
          await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${accessToken}` },
            body: JSON.stringify({
              message: {
                token: token,
                notification: { title, body },
                data: { type: 'birthday_alert', celebranteId: String(celebrante.idUsuario) }
              }
            })
          })
          notificationsSent++
        } catch (err) {
          console.error(`Error enviando notificación:`, err)
        }
      }
    }

    return new Response(JSON.stringify({ 
      message: "Proceso completado", 
      cumpleañeros: peopleHavingBirthday.length,
      notificacionesEnviadas: notificationsSent 
    }), { headers: { "Content-Type": "application/json" } })

  } catch (err) {
    console.error('Error CRÍTICO:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})