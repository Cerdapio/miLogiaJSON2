-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.base_user (
  idUsuario bigint,
  Nombre character varying,
  Usuario character varying,
  Contraseña character varying,
  Telefono character varying,
  FechaNacimiento date,
  Direccion character varying,
  CorreoElectronico character varying,
  Foto text,
  Activo boolean,
  auth_uuid uuid
);
CREATE TABLE public.catcAccion (
  idAccion bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  CONSTRAINT catcAccion_pkey PRIMARY KEY (idAccion)
);
CREATE TABLE public.catcConceptos (
  idConcepto bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  RequierePago boolean NOT NULL,
  RequiereGrado boolean NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcConceptos_pkey PRIMARY KEY (idConcepto)
);
CREATE TABLE public.catcDocumentos (
  idDocumento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  RequiereDescripcion boolean NOT NULL,
  RequiereGrado boolean NOT NULL,
  Activo boolean NOT NULL,
  Registro boolean NOT NULL DEFAULT true,
  Elavoracion boolean NOT NULL DEFAULT false,
  Solicitud boolean DEFAULT false,
  Pago boolean NOT NULL DEFAULT false,
  CONSTRAINT catcDocumentos_pkey PRIMARY KEY (idDocumento)
);
CREATE TABLE public.catcFormasPago (
  idFormaPago bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  RequiereFolio boolean NOT NULL,
  CONSTRAINT catcFormasPago_pkey PRIMARY KEY (idFormaPago)
);
CREATE TABLE public.catcGrados (
  idGrado bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Grado character varying NOT NULL,
  Descripcion character varying NOT NULL,
  Grupo character varying NOT NULL,
  Abreviatura character varying NOT NULL,
  Tratamiento character varying NOT NULL,
  Significado character varying NOT NULL,
  CONSTRAINT catcGrados_pkey PRIMARY KEY (idGrado)
);
CREATE TABLE public.catcGranLogia (
  idGranLogia bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  Grupo character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcGranLogia_pkey PRIMARY KEY (idGranLogia)
);
CREATE TABLE public.catcLogia (
  idLogia bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  Grupo character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcLogia_pkey PRIMARY KEY (idLogia)
);
CREATE TABLE public.catcPaletaDeColores (
  idPaletaDeColores bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idGrado bigint NOT NULL,
  C1 character varying NOT NULL,
  C2 character varying NOT NULL,
  C3 character varying NOT NULL,
  C4 character varying NOT NULL,
  CONSTRAINT catcPaletaDeColores_pkey PRIMARY KEY (idPaletaDeColores)
);
CREATE TABLE public.catcParentezcos (
  idParentezco bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcParentezcos_pkey PRIMARY KEY (idParentezco)
);
CREATE TABLE public.catcPerfiles (
  idPerfil bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  Nombre character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcPerfiles_pkey PRIMARY KEY (idPerfil)
);
CREATE TABLE public.catcPermisos (
  idPermiso bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Descripcion character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catcPermisos_pkey PRIMARY KEY (idPermiso)
);
CREATE TABLE public.catcUsuarios (
  idUsuario bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  Nombre character varying NOT NULL DEFAULT ''::character varying,
  Usuario character varying NOT NULL DEFAULT ''::character varying,
  Contraseña character varying NOT NULL DEFAULT ''::character varying,
  Telefono character varying NOT NULL DEFAULT ''::character varying,
  FechaNacimiento date NOT NULL DEFAULT '1900-01-01'::date,
  Direccion character varying NOT NULL DEFAULT ''::character varying,
  CorreoElectronico character varying NOT NULL DEFAULT ''::character varying,
  Foto text NOT NULL DEFAULT ''::text,
  Activo boolean NOT NULL DEFAULT true,
  auth_uuid uuid,
  CONSTRAINT catcUsuarios_pkey PRIMARY KEY (idUsuario)
);
CREATE TABLE public.catdConceptos (
  iddConcepto bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  idConcepto bigint NOT NULL,
  iddLogia bigint NOT NULL,
  idGrado bigint NOT NULL,
  Costo double precision NOT NULL,
  Activo boolean NOT NULL DEFAULT true,
  CONSTRAINT catdConceptos_pkey PRIMARY KEY (iddConcepto)
);
CREATE TABLE public.catdDocumentos (
  iddDocumento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idDocumento bigint NOT NULL,
  NombreCorto character varying NOT NULL,
  NombreLargo character varying NOT NULL,
  idGrado bigint NOT NULL,
  Activo boolean NOT NULL,
  idConcepto bigint NOT NULL DEFAULT '0'::bigint,
  CONSTRAINT catdDocumentos_pkey PRIMARY KEY (iddDocumento)
);
CREATE TABLE public.catdLogia (
  iddLogia bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idGranLogia bigint NOT NULL,
  idLogia bigint NOT NULL,
  Activo boolean NOT NULL DEFAULT true,
  CuentaBanco text,
  CONSTRAINT catdLogia_pkey PRIMARY KEY (iddLogia)
);
CREATE TABLE public.catdPerfilesPermisos (
  iddPerfil bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idPerfil bigint NOT NULL,
  iddPermiso bigint NOT NULL,
  CONSTRAINT catdPerfilesPermisos_pkey PRIMARY KEY (iddPerfil)
);
CREATE TABLE public.catdPermisos (
  iddPermiso bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idPermiso bigint NOT NULL,
  idAccion bigint NOT NULL,
  CONSTRAINT catdPermisos_pkey PRIMARY KEY (iddPermiso)
);
CREATE TABLE public.catdUsuario (
  iddUsuario bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  idUsuario bigint NOT NULL,
  idPerfil bigint NOT NULL,
  Fecha date NOT NULL,
  iddLogia bigint NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catdUsuario_pkey PRIMARY KEY (iddUsuario)
);
CREATE TABLE public.catdUsuarioEmergencias (
  idEmergencia bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idUsuario bigint NOT NULL,
  idParentezco bigint NOT NULL,
  Nombre character varying NOT NULL,
  Direccion character varying NOT NULL,
  Telefono character varying NOT NULL,
  Activo boolean NOT NULL,
  Beneficiario boolean DEFAULT false,
  Porcentaje bigint DEFAULT '0'::bigint,
  CONSTRAINT catdUsuarioEmergencias_pkey PRIMARY KEY (idEmergencia)
);
CREATE TABLE public.catdUsuarioGrado (
  idUsuarioGrado bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idUsuario bigint NOT NULL,
  idGrado bigint NOT NULL,
  Fecha date NOT NULL,
  iddLogia bigint NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT catdUsuarioGrado_pkey PRIMARY KEY (idUsuarioGrado)
);
CREATE TABLE public.documentos (
  coalesce jsonb
);
CREATE TABLE public.movcDocumentos (
  idMovDocumento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  iddDocumento bigint NOT NULL,
  idUsuario bigint NOT NULL,
  Descripcion character varying NOT NULL,
  Fecha date NOT NULL,
  Activo boolean,
  iddLogia bigint,
  Elavorado boolean NOT NULL DEFAULT false,
  CONSTRAINT movcDocumentos_pkey PRIMARY KEY (idMovDocumento)
);
CREATE TABLE public.movcPagos (
  idPago bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  idUsuario bigint NOT NULL,
  Importe double precision NOT NULL,
  Fecha date NOT NULL,
  idFormaPago bigint NOT NULL,
  Folio character varying NOT NULL,
  Activo boolean NOT NULL,
  CONSTRAINT movcPagos_pkey PRIMARY KEY (idPago)
);
CREATE TABLE public.movdPagos (
  iddPago bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idPago bigint NOT NULL,
  iddConcepto bigint NOT NULL,
  Cantidad double precision NOT NULL,
  CONSTRAINT movdPagos_pkey PRIMARY KEY (iddPago)
);
CREATE TABLE public.perfiles (
  coalesce jsonb
);