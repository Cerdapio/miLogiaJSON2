-- 1. Add TipoInput to catcConceptos for dynamic forms
ALTER TABLE public.catcConceptos 
ADD COLUMN TipoInput character varying DEFAULT 'ninguno'; -- 'texto', 'fecha', 'imagen', 'ninguno'

-- 2. Create Attendance Table (Relational: Logia -> Usuario -> Fecha)
CREATE TABLE public.relAsistencia (
  idAsistencia bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  iddLogia bigint NOT NULL,
  idUsuario bigint NOT NULL,
  Fecha date NOT NULL DEFAULT CURRENT_DATE,
  Asistio boolean NOT NULL DEFAULT false,
  Justificado boolean DEFAULT false,
  CONSTRAINT relAsistencia_pkey PRIMARY KEY (idAsistencia)
);

-- 3. HTML Templates (Machotes) Table
CREATE TABLE public.catdMachotes (
  idMachote bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  iddLogia bigint NOT NULL,
  Nombre character varying NOT NULL,
  ContenidoHTML text NOT NULL,
  EsPublico boolean DEFAULT false, -- If true, other lodges can use it as a template
  CONSTRAINT catdMachotes_pkey PRIMARY KEY (idMachote)
);

-- 4. Function to notify Secretary (Conceptual - needs corresponding Trigger or Edge Function)
-- This is just a placeholder ensuring the infrastructure exists if needed.
-- Real notification logic will be handled in Dart via NotificationService.
