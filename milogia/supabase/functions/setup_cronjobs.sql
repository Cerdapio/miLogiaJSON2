-- 1. Habilitar la extensión pg_cron (si no está habilitada)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Programar alerta de CUMPLEAÑOS (Todos los días a las 08:00 AM UTC)
-- Nota: 08:00 AM UTC suele ser madrugada en América.
SELECT cron.schedule(
  'birthday-alert-job',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url := 'https://[TU_PROYECTO].supabase.co/functions/v1/birthday-alert',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer [TU_SERVICE_ROLE_KEY]"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- 3. Programar alerta de RADIOS (Todos los días a las 09:00 AM UTC)
-- Esto procesará periodicidad (diaria, semanal, mensual) y recordatorios de vencimiento.
SELECT cron.schedule(
  'radio-alert-periodic-job',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://[TU_PROYECTO].supabase.co/functions/v1/radio-alert',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer [TU_SERVICE_ROLE_KEY]"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
