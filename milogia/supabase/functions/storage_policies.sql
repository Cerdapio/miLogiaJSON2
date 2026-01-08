-- 1. Insertar el bucket en la configuración de storage (si no existe)
-- Nota: Esto solo funciona si no lo creaste por el Dashboard.
INSERT INTO storage.buckets (id, name, public)
VALUES ('radios_docs', 'radios_docs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Permitir que cualquier usuario autenticado suba archivos
-- (Puedes restringirlo más adelante si deseas que solo Secretarios suban)
CREATE POLICY "Permitir subida a usuarios autenticados" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'radios_docs');

-- 3. Permitir que cualquiera lea los archivos (ya que es un bucket público)
CREATE POLICY "Permitir lectura pública" 
ON storage.objects FOR SELECT 
TO public 
USING (bucket_id = 'radios_docs');

-- 4. (Opcional) Permitir que el usuario borre sus propios archivos subidos
CREATE POLICY "Permitir borrar propios archivos" 
ON storage.objects FOR DELETE 
TO authenticated 
USING (bucket_id = 'radios_docs' AND auth.uid() = owner);
