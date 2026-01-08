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
    const { type, record } = await req.json()
    console.log(`--- Iniciando payment-alert tipo: ${type} ---`)

    // Validar payload
    if (!type || !record) {
      throw new Error('Faltan datos requeridos (type, record)')
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const accessToken = await getAccessToken()

    let recipients: string[] = []
    let notificationTitle = ''
    let notificationBody = ''

    // Lógica según el tipo de evento
    if (type === 'reported') {
      // EVENTO: Nuevo reporte de pago
      // Destinatarios: Tesoreros (idPerfil = 7) de la logia del usuario
      // record es de 'movcPagosReportados'
      const idLogia = record.iddLogia
      const monto = record.Monto

      const { data: tesoreros, error } = await supabase
        .from('catdUsuario')
        .select('fcm_token')
        .eq('iddLogia', idLogia)
        .eq('idPerfil', 7) // 7 = Tesorero (Asumiendo ID fijo, idealmente buscar por nombre)
        .eq('Activo', true)
        .not('fcm_token', 'is', null)

      if (error) {
        console.error('Error buscando tesoreros:', error)
      } else {
        recipients = tesoreros.map((u: any) => u.fcm_token)
      }

      notificationTitle = 'Nuevo Pago Reportado'
      notificationBody = `Se ha reportado un pago de $${monto}. Requiere validación.`

    } else if (type === 'validated') {
      // EVENTO: Pago validado
      // Puede venir de movcPagos (cash) o movcPagosReportados (transfer update)
      const idUsuario = record.idUsuario
      const monto = record.Importe || record.Monto // Importe en Pagos, Monto en Reportes
      const folio = record.Folio || record.FolioBancario || 'S/N'

      const { data: usuarios, error } = await supabase
        .from('catdUsuario')
        .select('fcm_token')
        .eq('idUsuario', idUsuario)
        .not('fcm_token', 'is', null)

      if (error) {
        console.error('Error buscando usuario:', error)
      } else if (usuarios && usuarios.length > 0) {
        recipients = usuarios.map((u: any) => u.fcm_token)
      }

      notificationTitle = 'Pago Validado'
      notificationBody = `Tu pago de $${monto} ha sido autorizado exitosamente.`

    } else if (type === 'rejected') {
      // EVENTO: Pago rechazado
      const idUsuario = record.idUsuario
      const motivo = record.NotasRevision || 'Sin motivo especificado'

      const { data: usuarios, error } = await supabase
        .from('catdUsuario')
        .select('fcm_token')
        .eq('idUsuario', idUsuario)
        .not('fcm_token', 'is', null)

      if (error) {
        console.error('Error buscando usuario para rechazo:', error)
      } else if (usuarios && usuarios.length > 0) {
        recipients = usuarios.map((u: any) => u.fcm_token)
      }

      notificationTitle = 'Transacción Rechazada'
      notificationBody = `Motivo: ${motivo}`
    }

    // Deduplicar tokens
    recipients = [...new Set(recipients)];
    console.log(`Enviando a ${recipients.length} destinatarios.`)

    // Enviar notificaciones
    let successCount = 0
    for (const token of recipients) {
      try {
        await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${accessToken}` },
          body: JSON.stringify({
            message: {
              token: token,
              notification: { 
                title: notificationTitle, 
                body: notificationBody 
              },
              data: { 
                type: 'payment_alert',
                eventType: type,
                id: String(record.idPago || record.idReporte || 0)
              }
            }
          })
        })
        successCount++
      } catch (e) {
        console.error(`Error enviando notificación a ${token}:`, e)
      }
    }

    return new Response(JSON.stringify({ message: "Procesado", success_count: successCount }), { 
      headers: { "Content-Type": "application/json" } 
    })

  } catch (err) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
