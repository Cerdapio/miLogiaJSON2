import 'package:flutter/material.dart';
import 'dart:ui';

class L10n {
  static bool isEn(BuildContext context) => Localizations.localeOf(context).languageCode == 'en';
  static bool isEnStatic() => PlatformDispatcher.instance.locale.languageCode == 'en';

  static String appTitle() => isEnStatic() ? 'My Lodge App' : 'Mi Logia App';

  // --- Login Screen ---
  static String loginTitle(BuildContext context) => isEn(context) ? 'MY LODGE' : 'MI LOGIA';
    static String emailLabel(BuildContext context) => isEn(context) ? 'Email Address' : 'Correo Electrónico';
  static String emailHint(BuildContext context) => isEn(context) ? 'e.g. name@domain.com' : 'ej. nombre@dominio.com';
  static String emailError(BuildContext context) => isEn(context) ? 'Enter a valid email' : 'Ingresa un correo electrónico válido';
  static String passwordLabel(BuildContext context) => isEn(context) ? 'Password' : 'Contraseña';
  static String passwordError(BuildContext context) => isEn(context) ? 'Please enter your password' : 'Por favor ingresa tu contraseña';
  static String loginButton(BuildContext context) => isEn(context) ? 'LOGIN' : 'INGRESAR';
  static String fingerprintTooltip(BuildContext context) => isEn(context) ? 'Enter with fingerprint' : 'Ingresar con huella digital';
  static String fingerprintLabel(BuildContext context) => isEn(context) ? 'Login with fingerprint' : 'Ingresar con huella';
  static String profileSelectionTitle(BuildContext context) => isEn(context) ? 'Profile Selection' : 'Selección de Perfil';
  static String profileSelectionBody(BuildContext context) => isEn(context) ? 'Please select the group you want to work with:' : 'Por favor, selecciona el grupo con el que deseas trabajar:';
  static String groupLabel(BuildContext context) => isEn(context) ? 'Group / Lodge' : 'Grupo / Logia';
  static String biometricNoSupport(BuildContext context) => isEn(context) ? 'Device does not support biometric authentication.' : 'El dispositivo no soporta autenticación biométrica.';
  static String biometricReason(BuildContext context) => isEn(context) ? 'Use your fingerprint or face to login' : 'Usa tu huella o rostro para ingresar';
  static String authSuccess(BuildContext context) => isEn(context) ? 'Authentication successful. Loading data...' : 'Autenticación exitosa. Cargando datos...';
  static String credentialsNotFound(BuildContext context) => isEn(context) ? 'No saved credentials found. Please login manually once.' : 'No se encontraron credenciales guardadas. Por favor, inicia sesión manualmente una vez.';
  static String biometricError(BuildContext context) => isEn(context) ? 'Biometric error' : 'Error de biometría';
  static String loginCredentialsError(BuildContext context) => isEn(context) ? 'Incorrect username or password.' : 'Usuario o contraseña incorrectos.';

  // --- Login Screen - Additional ---
  static String sessionUnavailable(BuildContext context) => isEn(context) ? 'Session unavailable after authentication. Invalid credentials.' : 'Sesión no disponible después de la autenticación. Credenciales inválidas.';
  static String noProfilesAssigned(BuildContext context) => isEn(context) ? 'User has no profiles assigned, but the session is valid.' : 'El usuario no tiene perfiles asignados, pero la sesión es válida.';
  static String userKeyNotFound(BuildContext context) => isEn(context) ? 'Server response valid, but "user" key not found.' : 'Respuesta de servidor válida, pero no se encontró la clave "user".';
  static String rpcFormatError(BuildContext context) => isEn(context) ? 'Unexpected RPC response format.' : 'Formato de respuesta de la RPC inesperado.';
  static String extraDataError(BuildContext context) => isEn(context) ? 'Error obtaining additional data: ' : 'Error al obtener datos adicionales: ';
  static String authGenError(BuildContext context) => isEn(context) ? 'Authentication error: ' : 'Error de autenticación: ';
  static String unexpectedError(BuildContext context) => isEn(context) ? 'An unexpected error occurred: ' : 'Ocurrió un error inesperado: ';
  static String loginSuccessNoProfiles(BuildContext context) => isEn(context) ? 'Login successful, but no profiles assigned.' : 'Inicio de sesión correcto, pero no tienes perfiles asignados.';

  // --- Home Screen & Profiles ---
  static String myProfile(BuildContext context) => isEn(context) ? 'MY PROFILE' : 'MI PERFIL';
  static String contactData(BuildContext context) => isEn(context) ? 'Contact Info' : 'Datos de Contacto';
  static String phoneLabel(BuildContext context) => isEn(context) ? 'Phone' : 'Teléfono';
  static String addressLabel(BuildContext context) => isEn(context) ? 'Address' : 'Dirección';
  static String quoteOfTheDay(BuildContext context) => isEn(context) ? 'Quote of the Day' : 'Frase del Día';
  static String errorLoadingQuote(BuildContext context) => isEn(context) ? 'Error loading quote.' : 'Error al cargar la frase.';
  static String noQuoteAvailable(BuildContext context) => isEn(context) ? 'No quote available.' : 'Sin frase disponible.';
  static String createMinutes(BuildContext context) => isEn(context) ? 'CREATE MINUTES' : 'LEVANTAR ACTA';
  static String profileUpdated(BuildContext context) => isEn(context) ? 'Profile picture updated successfully.' : 'Foto de perfil actualizada correctamente.';

  // --- Actas Screen ---
  static String venerableMaster(BuildContext context) => isEn(context) ? 'Worshipful Master' : 'Venerable Maestro';
  static String secretary(BuildContext context) => isEn(context) ? 'Secretary' : 'Secretario';
  static String orator(BuildContext context) => isEn(context) ? 'Orator' : 'Orador';
  static String firstWarden(BuildContext context) => isEn(context) ? 'Senior Warden' : 'Primer Vigilante';
  static String secondWarden(BuildContext context) => isEn(context) ? 'Junior Warden' : 'Segundo Vigilante';
  static String masterCeremonies(BuildContext context) => isEn(context) ? 'Master of Ceremonies' : 'Maestro de Ceremonias';
  static String firstExpert(BuildContext context) => isEn(context) ? 'Senior Expert' : 'Primer Experto';
  static String secondExpert(BuildContext context) => isEn(context) ? 'Junior Expert' : 'Segundo Experto';
  static String hospitaler(BuildContext context) => isEn(context) ? 'Almoner' : 'Hospitalario';
  static String standardBearer(BuildContext context) => isEn(context) ? 'Standard Bearer' : 'Porta Estandarte';
  static String innerGuard(BuildContext context) => isEn(context) ? 'Inner Guard' : 'Guarda Templo Interior';

  static String generalData(BuildContext context) => isEn(context) ? 'General Data' : 'Datos Generales';
  static String lodgeBoard(BuildContext context) => isEn(context) ? 'Lodge Board' : 'Cuadro Logial';
  static String worksPresented(BuildContext context) => isEn(context) ? 'Works Presented' : 'Trabajos Presentados';
  static String proposalsBag(BuildContext context) => isEn(context) ? 'Proposals Bag' : 'Saco de Proposiciones';
  static String charityBag(BuildContext context) => isEn(context) ? 'Charity Bag' : 'Saco de Beneficencia';
  static String generatePreview(BuildContext context) => isEn(context) ? 'GENERATE PREVIEW' : 'GENERAR PREVISUALIZACIÓN';
  static String flexibleEditor(BuildContext context) => isEn(context) ? 'GO TO FLEXIBLE EDITOR' : 'IR A EDITOR FLEXIBLE (NUEVO)';
  static String dateLabel(BuildContext context) => isEn(context) ? 'Date' : 'Fecha';
  static String hourLabel(BuildContext context) => isEn(context) ? 'Time' : 'Hora';
  static String meetingType(BuildContext context) => isEn(context) ? 'Meeting Type' : 'Tipo de Tenida';
  static String addWork(BuildContext context) => isEn(context) ? 'ADD WORK' : 'AGREGAR TRABAJO';
  static String registerExcuse(BuildContext context) => isEn(context) ? 'REGISTER EXCUSE' : 'REGISTRAR DISCULPA';
  static String amountCollected(BuildContext context) => isEn(context) ? 'Amount Collected' : 'Monto Recaudado';
  static String addWorkTitle(BuildContext context) => isEn(context) ? 'Add Work' : 'Agregar Trabajo';
  static String authorLabel(BuildContext context) => isEn(context) ? 'Author' : 'Autor';
  static String workTypeLabel(BuildContext context) => isEn(context) ? 'Work Type' : 'Tipo de Trabajo';
  static String obligatorySubject(BuildContext context) => isEn(context) ? 'Is it a degree compulsory topic?' : '¿Es Tema Obligatorio del Grado?';
  static String selectSubject(BuildContext context) => isEn(context) ? 'Select topic...' : 'Seleccione el tema...';
  static String freeSubject(BuildContext context) => isEn(context) ? 'Work Title (Free Topic)' : 'Título del Trabajo (Tema Libre)';
  static String registerExcuseTitle(BuildContext context) => isEn(context) ? 'Register Excuse' : 'Registrar Disculpa';
  static String absentBrother(BuildContext context) => isEn(context) ? 'Absent Brother' : 'H:. Ausente';
  static String excusingBrother(BuildContext context) => isEn(context) ? 'Excusing Brother' : 'H:. que disculpa';
  static String previewMinutes(BuildContext context) => isEn(context) ? 'Minutes Preview' : 'Vista Previa del Acta';
  static String saveSimulation(BuildContext context) => isEn(context) ? 'Minutes saved (Simulation)' : 'Acta guardada (Simulación)';
  static String confirmAndSave(BuildContext context) => isEn(context) ? 'Confirm and Save' : 'Confirmar y Guardar';
  static String close(BuildContext context) => isEn(context) ? 'Close' : 'Cerrar';
  static String cancel(BuildContext context) => isEn(context) ? 'Cancel' : 'Cancelar';
  static String add(BuildContext context) => isEn(context) ? 'Add' : 'Agregar';

  // --- App Drawer ---
  static String superAdmin(BuildContext context) => isEn(context) ? 'Super Admin' : 'Super Admin';
  static String homeProfile(BuildContext context) => isEn(context) ? 'Home / My Profile' : 'Inicio / Mi Perfil';
  static String editProfile(BuildContext context) => isEn(context) ? 'Edit Profile' : 'Editar Perfil';
  static String emergencyContacts(BuildContext context) => isEn(context) ? 'Emergency Contacts' : 'Contactos Emergencia';
  static String myPayments(BuildContext context) => isEn(context) ? 'My Payments' : 'Mis Pagos';
  static String myDocuments(BuildContext context) => isEn(context) ? 'My Documents' : 'Mis Documentos';
  static String reportTransfer(BuildContext context) => isEn(context) ? 'Report Transfer' : 'Reportar Transferencia';
  static String emitRadio(BuildContext context) => isEn(context) ? 'Emit Radio' : 'Emitir Radio';
  static String secretariat(BuildContext context) => isEn(context) ? 'Secretariat' : 'Secretaría';
  static String bookOfMinutes(BuildContext context) => isEn(context) ? 'Book of Minutes' : 'Libro de actas';
  static String treasury(BuildContext context) => isEn(context) ? 'Treasury' : 'Tesorería';
  static String validateTransfers(BuildContext context) => isEn(context) ? 'Validate Transfers' : 'Validar Transferencias';
  static String lodgePaymentCash(BuildContext context) => isEn(context) ? 'Lodge Collection (Cash)' : 'Cobro en Logia (Efectivo)';
  static String changeProfile(BuildContext context) => isEn(context) ? 'Change Profile' : 'Cambiar Perfil';
  static String logoutLabel(BuildContext context) => isEn(context) ? 'Logout' : 'Cerrar Sesión';

  // --- Profile Edit ---
  static String editPersonalTitle(BuildContext context) => isEn(context) ? 'Edit Personal Data' : 'Editar Datos Personales';
  static String successfulUpdate(BuildContext context) => isEn(context) ? 'Update Successful' : 'Actualización Exitosa';
  static String dataUpdatedMsg(BuildContext context) => isEn(context) ? 'Your personal data has been updated.' : 'Tus datos personales han sido actualizados.';
  static String changePasswordTitle(BuildContext context) => isEn(context) ? 'Change Password' : 'Cambiar Contraseña';
  static String currentPasswordLabel(BuildContext context) => isEn(context) ? 'Current Password' : 'Contraseña Anterior';
  static String newPasswordLabel(BuildContext context) => isEn(context) ? 'New Password' : 'Nueva Contraseña';
  static String confirmPasswordLabel(BuildContext context) => isEn(context) ? 'Confirm New Password' : 'Confirmar Nueva Contraseña';
  static String passwordLengthError(BuildContext context) => isEn(context) ? 'New password must be at least 6 characters.' : 'La nueva contraseña debe tener al menos 6 caracteres.';
  static String confirmPasswordError(BuildContext context) => isEn(context) ? 'Confirm the new password.' : 'Confirma la nueva contraseña.';
  static String passwordsNoMatch(BuildContext context) => isEn(context) ? 'Passwords do not match.' : 'Las contraseñas no coinciden.';
  static String saveButton(BuildContext context) => isEn(context) ? 'Save' : 'Guardar';
  static String cancelButton(BuildContext context) => isEn(context) ? 'Cancel' : 'Cancelar';
  static String adminToolsTitle(BuildContext context) => isEn(context) ? 'Administration Tools' : 'Herramientas de Administración';
  static String adminToolsSub(BuildContext context) => isEn(context) ? 'Profile, lodge and degree management' : 'Gestión de perfiles, logias y grados';
  static String assignRoleTitle(BuildContext context) => isEn(context) ? 'Assign/Update User Role' : 'Asignar/Actualizar Rol de Usuario';
  static String userToEditLabel(BuildContext context) => isEn(context) ? 'User to Edit' : 'Usuario a Editar';
  static String newProfileLabel(BuildContext context) => isEn(context) ? 'New Profile' : 'Nuevo Perfil';
  static String newGradeLabel(BuildContext context) => isEn(context) ? 'New Degree' : 'Nuevo Grado';
  static String assignRoleButton(BuildContext context) => isEn(context) ? 'Assign Role (SP 8)' : 'Asignar Rol (SP 8)';
  static String registerNewUserButton(BuildContext context) => isEn(context) ? 'Register New User' : 'Registrar Nuevo Usuario';
  static String registerNewMemberTitle(BuildContext context) => isEn(context) ? 'Register New Member' : 'Registrar Nuevo Miembro';
  static String fullNameLabel(BuildContext context) => isEn(context) ? 'Full Name' : 'Nombre Completo';
  static String requiredError(BuildContext context) => isEn(context) ? 'Required' : 'Requerido';
  static String invalidEmailError(BuildContext context) => isEn(context) ? 'Invalid email' : 'Correo inválido';
  static String minCharsError(BuildContext context) => isEn(context) ? 'Minimum 6 characters' : 'Mínimo 6 caracteres';
  static String selectProfileError(BuildContext context) => isEn(context) ? 'Select a profile' : 'Selecciona un perfil';
  static String selectGradeError(BuildContext context) => isEn(context) ? 'Select a degree' : 'Selecciona un grado';
  static String registerButton(BuildContext context) => isEn(context) ? 'Register' : 'Registrar';
  static String savingLabel(BuildContext context) => isEn(context) ? 'Saving...' : 'Guardando...';
  static String personalDataTab(BuildContext context) => isEn(context) ? 'My Data' : 'Mis Datos';
  static String adminToolsTab(BuildContext context) => isEn(context) ? 'Admin Tools' : 'Admin Tools';
  static String photoNote(BuildContext context) => isEn(context) ? '**Note:** Profile picture is updated from Home.' : '**Nota:** La foto de perfil se actualiza desde el Home.';
  static String editProfileTitle(BuildContext context) => isEn(context) ? 'Edit My Profile' : 'Editar Mi Perfil';
  static String editAdminTitle(BuildContext context) => isEn(context) ? 'Edit Profile / Admin' : 'Editar Perfil / Admin';
  static String gradeLabel(BuildContext context) => isEn(context) ? 'Degree' : 'Grado';
  static String profileLabel(BuildContext context) => isEn(context) ? 'Profile' : 'Perfil';
  static String dobLabel(BuildContext context) => isEn(context) ? 'Date of Birth (YYYY-MM-DD)' : 'Fecha de Nacimiento (YYYY-MM-DD)';
  static String savePersonalData(BuildContext context) => isEn(context) ? 'Save Personal Data' : 'Guardar Datos Personales';

  // --- Actas Editor ---
  static String editorTitle(BuildContext context) => isEn(context) ? 'MINUTES EDITOR' : 'EDITOR DE ACTA';
  static String signDocument(BuildContext context) => isEn(context) ? 'Sign Document' : 'Firmar Documento';
  static String clean(BuildContext context) => isEn(context) ? 'Clear' : 'Limpiar';
  static String insert(BuildContext context) => isEn(context) ? 'Insert' : 'Insertar';
  static String uploadingSignError(BuildContext context) => isEn(context) ? 'Error uploading signature:' : 'Error al subir firma:';
  static String minutesSavedSuccess(BuildContext context) => isEn(context) ? 'Minutes saved successfully' : 'Acta guardada correctamente';
  static String saveError(BuildContext context) => isEn(context) ? 'Error saving:' : 'Error al guardar:';
  static String saveDatabaseTooltip(BuildContext context) => isEn(context) ? 'Save to Database' : 'Guardar en Base de Datos';
  static String exportPdfTooltip(BuildContext context) => isEn(context) ? 'Export to PDF' : 'Exportar a PDF';
  static String insertSignButton(BuildContext context) => isEn(context) ? 'Insert Signature' : 'Insertar Firma';
  static String editorInstruction(BuildContext context) => isEn(context) ? 'Edit the contents of the minutes. Use the signature button to add digital signatures.' : 'Edite el contenido del acta. Use el botón de firma para añadir firmas digitales.';
  static String editorHint(BuildContext context) => isEn(context) ? 'Write the content of the minutes here...' : 'Escriba el contenido del acta aquí...';
  static String minutesDocTitle(BuildContext context) => isEn(context) ? 'MINUTES OF WORKS' : 'ACTA DE TRABAJOS';

  // --- Payments ---
  static String paymentsTitle(BuildContext context) => isEn(context) ? 'Payments' : 'Pagos';
  static String validateTab(BuildContext context) => isEn(context) ? 'Validate' : 'Validar';
  static String collectionTab(BuildContext context) => isEn(context) ? 'Collection' : 'Cobro';
  static String myPaymentsTab(BuildContext context) => isEn(context) ? 'My Payments' : 'Mis Pagos';
  static String paymentsApproved(BuildContext context) => isEn(context) ? 'Payment approved successfully.' : 'Pago aprobado con éxito.';
  static String dataMissing(BuildContext context) => isEn(context) ? 'Missing Data' : 'Faltan datos';
  static String selectMemberMsg(BuildContext context) => isEn(context) ? 'Select a member and at least one concept.' : 'Selecciona un miembro y al menos un concepto.';
  static String paymentRegisteredPrefix(BuildContext context) => isEn(context) ? 'Charge of ' : 'Cobro de ';
  static String registeredSuccess(BuildContext context) => isEn(context) ? ' registered successfully.' : ' registrado con éxito.';
  static String errorApproving(BuildContext context) => isEn(context) ? 'Could not approve:' : 'No se pudo aprobar:';
  static String historyTitle(BuildContext context) => isEn(context) ? 'Payment History' : 'Historial de Pagos';
  static String noPayments(BuildContext context) => isEn(context) ? 'You have no registered payments.' : 'No tienes pagos registrados.';
  static String newPayment(BuildContext context) => isEn(context) ? 'New Payment' : 'Nuevo Pago';
  static String payTooltip(BuildContext context) => isEn(context) ? 'Generate Payment Reference' : 'Generar Referencia de Pago';
  static String approveButton(BuildContext context) => isEn(context) ? 'Approve' : 'Aprobar';
  static String rejectButton(BuildContext context) => isEn(context) ? 'Reject' : 'Rechazar';
  static String paymentSlipTitle(BuildContext context) => isEn(context) ? 'Payment Slip Generated' : 'Papeleta de Pago Generada';
  static String referenceLabel(BuildContext context) => isEn(context) ? 'Reference:' : 'Referencia:';
  static String conceptLabel(BuildContext context) => isEn(context) ? 'Concept:' : 'Concepto:';
  static String destinationAccountLabel(BuildContext context) => isEn(context) ? 'Destination account:' : 'Cuenta destino:';
  static String amountToPayLabel(BuildContext context) => isEn(context) ? 'Amount to pay:' : 'Importe a pagar:';
  static String paymentInstruction(BuildContext context) => isEn(context) ? 'Make the transfer using EXACTLY this reference. Keep this screenshot.' : 'Realiza la transferencia usando EXACTAMENTE esta referencia. Conserva esta captura.';
  static String understoodButton(BuildContext context) => isEn(context) ? 'Understood' : 'Entendido';
  static String paymentDetailTitlePrefix(BuildContext context) => isEn(context) ? 'Payment Detail #' : 'Detalle Pago #';
  static String paymentValidated(BuildContext context) => isEn(context) ? 'PAYMENT VALIDATED' : 'PAGO VALIDADO';
  static String pendingValidation(BuildContext context) => isEn(context) ? 'PENDING VALIDATION' : 'PENDIENTE DE VALIDAR';
  static String conceptsLabel(BuildContext context) => isEn(context) ? 'Concepts:' : 'Conceptos:';
  static String loadingDetails(BuildContext context) => isEn(context) ? 'Loading details or no concepts...' : 'Cargando detalles o sin conceptos...';
  static String totalLabel(BuildContext context) => isEn(context) ? 'TOTAL' : 'TOTAL';
  static String treasuryFolio(BuildContext context) => isEn(context) ? 'Treasury Folio:' : 'Folio Tesorería:';
  static String closeButton(BuildContext context) => isEn(context) ? 'Close' : 'Cerrar';
  static String addConceptButton(BuildContext context) => isEn(context) ? 'Add another concept' : 'Agregar otro concepto';
  static String generateReferenceButton(BuildContext context) => isEn(context) ? 'Generate Reference' : 'Generar Referencia';
  static String quantityLabel(BuildContext context) => isEn(context) ? 'Quantity: ' : 'Cantidad: ';
  static String memberToChargeLabel(BuildContext context) => isEn(context) ? 'Member to Charge' : 'Miembro a Cobrar';
  static String folioManualLabel(BuildContext context) => isEn(context) ? 'Folio (Manual)' : 'Folio (Manual)';
  static String registerChargeButton(BuildContext context) => isEn(context) ? 'Register Charge' : 'Registrar Cobro';
  static String pendingReportsTitle(BuildContext context) => isEn(context) ? 'Pending Reports' : 'Reportes Pendientes';
  static String noPendingReports(BuildContext context) => isEn(context) ? 'No pending transfer reports.' : 'No hay reportes de transferencia pendientes.';
  static String notConfiguredAccount(BuildContext context) => isEn(context) ? 'N/A - Account not configured' : 'N/A - Cuenta no configurada';
  static String myPaymentsHeader(BuildContext context) => isEn(context) ? 'Payments of:' : 'Pagos de:';
  static String treasuryTitlePrefix(BuildContext context) => isEn(context) ? 'Treasury - ' : 'Tesorería - ';
  static String accountStatement(BuildContext context) => isEn(context) ? 'Account Statement' : 'Estado de Cuenta';
  static String uploadStatementsTooltip(BuildContext context) => isEn(context) ? 'Upload Account Statements' : 'Subir Estados de Cuenta';
  static String processedStatus(BuildContext context) => isEn(context) ? 'Processed' : 'Procesado';
  static String pendingStatus(BuildContext context) => isEn(context) ? 'Pending' : 'Pendiente';
  static String noTransfersToValidate(BuildContext context) => isEn(context) ? 'No pending transfers to validate.' : 'No hay transferencias por validar.';
  static String linkedToPayment(BuildContext context) => isEn(context) ? 'LINKED TO PAYMENT #' : 'VINCULADO A PAGO #';
  static String payDateLabel(BuildContext context) => isEn(context) ? 'Real Payment Date:' : 'Fecha Pago Real:';
  static String bankFolioLabel(BuildContext context) => isEn(context) ? 'Bank Folio:' : 'Folio Bancario:';
  static String rejectLabel(BuildContext context) => isEn(context) ? 'REJECT' : 'RECHAZAR';
  static String approveLabel(BuildContext context) => isEn(context) ? 'APPROVE' : 'APROBAR';
  static String rejectPaymentTitle(BuildContext context) => isEn(context) ? 'Reject Payment' : 'Rechazar Pago';
  static String rejectReasonLabel(BuildContext context) => isEn(context) ? 'Reason for rejection' : 'Motivo del rechazo';
  static String stepSelectMember(BuildContext context) => isEn(context) ? '1. Select Member' : '1. Seleccionar Miembro';
  static String hintSelectBrother(BuildContext context) => isEn(context) ? 'Select a member' : 'Selecciona un hermano';
  static String stepConcepts(BuildContext context) => isEn(context) ? '2. Concepts' : '2. Conceptos';
  static String addButton(BuildContext context) => isEn(context) ? 'Add' : 'Agregar';
  static String addFirstConcept(BuildContext context) => isEn(context) ? '+ Add first concept' : '+ Agregar primer concepto';
  static String stepFolio(BuildContext context) => isEn(context) ? '3. Physical Receipt Folio' : '3. Folio Recibo Físico';
  static String folioHint(BuildContext context) => isEn(context) ? 'Ex: A-1234' : 'Ej: A-1234';
  static String totalToCharge(BuildContext context) => isEn(context) ? 'TOTAL TO CHARGE:' : 'TOTAL A COBRAR:';
  static String registerChargeButtonUpper(BuildContext context) => isEn(context) ? 'REGISTER CHARGE' : 'REGISTRAR COBRO';
  static String addConceptTitle(BuildContext context) => isEn(context) ? 'Add Concept' : 'Añadir Concepto';
  static String quantityPrefix(BuildContext context) => isEn(context) ? 'Qty: ' : 'Cant: ';
  static String amountLabel(BuildContext context) => isEn(context) ? 'Amount: ' : 'Monto: ';
  static String errorLoadingPagos(BuildContext context) => isEn(context) ? 'Error loading payments.' : 'Error al cargar pagos.';

  // --- Documents ---
  static String myDocumentsTitle(BuildContext context) => isEn(context) ? 'My Documents' : 'Mis Documentos';
  static String requestDocumentTitle(BuildContext context) => isEn(context) ? 'Document Request' : 'Solicitud de Documento';
  static String incompleteData(BuildContext context) => isEn(context) ? 'Incomplete Data' : 'Datos incompletos';
  static String selectGradeMsg(BuildContext context) => isEn(context) ? 'Please select a grade.' : 'Por favor selecciona un grado.';
  static String requireDescriptionMsg(BuildContext context) => isEn(context) ? 'This document requires a description or reason.' : 'Este documento requiere una descripción o motivo.';
  static String configError(BuildContext context) => isEn(context) ? 'Configuration Error' : 'Error de Configuración';
  static String noCostoFound(BuildContext context) => isEn(context) ? 'No cost was found for this document in your Lodge.' : 'No se encontró costo para este documento en tu Logia.';
  static String requestSentTitle(BuildContext context) => isEn(context) ? 'Request Sent' : 'Solicitud Enviada';
  static String requestSentMsgPrefix(BuildContext context) => isEn(context) ? 'Your request for ' : 'Tu solicitud de ';
  static String requestSentMsgSuffix(BuildContext context) => isEn(context) ? ' has been registered.' : ' ha sido registrada.';
  static String referenceGeneratedTitle(BuildContext context) => isEn(context) ? 'Reference Generated' : 'Referencia Generada';
  static String referenceGeneratedFor(BuildContext context) => isEn(context) ? 'The reference has been generated for: ' : 'Se ha generado la referencia para: ';
  static String accountDestLabel(BuildContext context) => isEn(context) ? 'Destination Account:' : 'Cuenta Destino:';
  static String importeLabel(BuildContext context) => isEn(context) ? 'Amount:' : 'Importe:';
  static String labelNoPermissionsDocs(BuildContext context) => isEn(context) ? 'You do not have permission to request documents.' : 'No tienes permisos para solicitar documentos.';
  static String labelDocType(BuildContext context) => isEn(context) ? 'Document Type' : 'Tipo de Documento';
  static String labelGradeMax(BuildContext context) => isEn(context) ? 'Grade (Max: ' : 'Grado (Max: ';
  static String labelNoGradesAvailable(BuildContext context) => isEn(context) ? 'No grades available (Max: ' : 'No hay grados disponibles (Max: ';
  static String labelDescriptionReason(BuildContext context) => isEn(context) ? 'Description / Reason' : 'Descripción / Motivo';
  static String labelCosto(BuildContext context) => isEn(context) ? 'Cost: ' : 'Costo: ';
  static String buttonPayRequest(BuildContext context) => isEn(context) ? 'Pay and Request' : 'Pagar y Solicitar';
  static String buttonRequestOnly(BuildContext context) => isEn(context) ? 'Request' : 'Solicitar';
  static String labelPersonalLibrary(BuildContext context) => isEn(context) ? 'Personal Library' : 'Biblioteca Personal';
  static String labelDocsFromLogiaSuffix(BuildContext context) => isEn(context) ? ' documents from this Lodge' : ' documentos de esta Logia';
  static String labelOfficialRadios(BuildContext context) => isEn(context) ? 'Official Communications' : 'Comunicados Oficiales';
  static String labelNoDocsFound(BuildContext context) => isEn(context) ? 'You have no documents.' : 'No tienes documentos.';
  static String labelGeneralDocs(BuildContext context) => isEn(context) ? 'General Documents' : 'Documentos Generales';
  static String labelGradePrefix(BuildContext context) => isEn(context) ? 'Grade ' : 'Grado ';
  static String labelNoMembersFound(BuildContext context) => isEn(context) ? 'No members found.' : 'No se encontraron miembros.';

  // --- Emergencies ---
  static String emergenciesTitle(BuildContext context) => isEn(context) ? 'Emergency Contacts' : 'Contactos de Emergencia';
  static String contactAdded(BuildContext context) => isEn(context) ? 'Contact added.' : 'Contacto agregado.';
  static String contactUpdated(BuildContext context) => isEn(context) ? 'Contact updated.' : 'Contacto actualizado.';
  static String contactDeleted(BuildContext context) => isEn(context) ? 'Contact deleted.' : 'Contacto eliminado.';
  static String locationPermissionDenied(BuildContext context) => isEn(context) ? 'Location permissions denied.' : 'Permisos de ubicación denegados.';
  static String alertSentSuccess(BuildContext context) => isEn(context) ? 'Alert sent successfully.' : 'Alerta enviada correctamente.';
  static String assistanceRequestTitle(BuildContext context) => isEn(context) ? 'Assistance Request' : 'Solicitud de Auxilio';
  static String assistanceTypeLabel(BuildContext context) => isEn(context) ? 'Assistance Type' : 'Tipo de ayuda';
  static String medHelp(BuildContext context) => isEn(context) ? 'Medical' : 'Médico';
  static String mechHelp(BuildContext context) => isEn(context) ? 'Mechanical' : 'Mecánico';
  static String secHelp(BuildContext context) => isEn(context) ? 'Security' : 'Seguridad';
  static String vialHelp(BuildContext context) => isEn(context) ? 'Roadside' : 'Vial';
  static String otherHelp(BuildContext context) => isEn(context) ? 'Other' : 'Otro';
  static String detailsOptionalLabel(BuildContext context) => isEn(context) ? 'Details (optional)' : 'Detalles (opcional)';
  static String sendAssistanceButton(BuildContext context) => isEn(context) ? 'Send Assistance' : 'Enviar Auxilio';
  static String editContactTitle(BuildContext context) => isEn(context) ? 'Edit Contact' : 'Editar contacto';
  static String newContactTitle(BuildContext context) => isEn(context) ? 'New Contact' : 'Nuevo contacto';
  static String nameLabel(BuildContext context) => isEn(context) ? 'Name' : 'Nombre';
  static String relationshipLabel(BuildContext context) => isEn(context) ? 'Relationship' : 'Parentezco';
  static String beneficiaryLabel(BuildContext context) => isEn(context) ? 'Beneficiary' : 'Beneficiario';
  static String percentageLabel(BuildContext context) => isEn(context) ? 'Percentage' : 'Porcentaje';
  static String selectRelationshipMsg(BuildContext context) => isEn(context) ? 'Select relationship' : 'Seleccione parentezco';
  static String relationshipPrefix(BuildContext context) => isEn(context) ? 'Relationship: ' : 'Parentezco: ';
  static String unknown(BuildContext context) => isEn(context) ? 'Unknown' : 'Desconocido';
  static String confirmDeleteTitle(BuildContext context) => isEn(context) ? 'Confirm Deletion' : 'Confirmar eliminación';
  static String deleteContactConfirmPrefix(BuildContext context) => isEn(context) ? 'Delete contact "' : 'Eliminar contacto "';
  static String yourEmergencyContacts(BuildContext context) => isEn(context) ? 'Your Emergency Contacts' : 'Tus contactos de emergencia';
  static String xiaomiSettingsTitle(BuildContext context) => isEn(context) ? 'Xiaomi/MIUI Settings' : 'Configuración para Xiaomi/MIUI';
  static String xiaomiSettingsMsg(BuildContext context) => isEn(context) ? 'To allow the alert to wake your device, you must enable "Show on lock screen" in the following screen.' : 'Para que la alerta despierte tu equipo, debes activar "Mostrar en pantalla de bloqueo" en la siguiente pantalla.';
  static String configureDirectButton(BuildContext context) => isEn(context) ? 'Configure Direct' : 'Configurar Directo';
  static String panicButton(BuildContext context) => isEn(context) ? 'PANIC' : 'PÁNICO';
  static String assistanceButton(BuildContext context) => isEn(context) ? 'ASSISTANCE' : 'AUXILIO';
  static String noEmergencyContacts(BuildContext context) => isEn(context) ? 'You have no emergency contacts.' : 'No tienes contactos de emergencia.';

  // --- Panic Alert ---
  static String panicAlertTitle(BuildContext context) => isEn(context) ? 'PANIC ALERT' : 'ALERTA DE PÁNICO';
  static String assistanceRequestTitleUpper(BuildContext context) => isEn(context) ? 'ASSISTANCE REQUEST' : 'SOLICITUD DE AUXILIO';
  static String brotherLabel(BuildContext context) => isEn(context) ? 'Brother' : 'Hermano';
  static String unknownBrotherLabel(BuildContext context) => isEn(context) ? 'Unknown Brother' : 'Hermano desconocido';
  static String distanceLabel(BuildContext context) => isEn(context) ? 'Distance' : 'Distancia';
  static String callButton(BuildContext context) => isEn(context) ? 'CALL' : 'LLAMAR';
  static String goNowButton(BuildContext context) => isEn(context) ? 'GO NOW' : 'IR AHORA';
  static String needsHelp(String name) => isEnStatic() ? '$name needs immediate help.' : 'El $name necesita ayuda inmediata.';


  // --- Super Admin ---
  static List<String> lodgeGroups(BuildContext context) => isEn(context) 
    ? ["Symbolic Degrees", "Capitular Lodges of Perfection", "Chapters of Knights Rose Croix", "Areopagi of Knights Kadosh", "Consistories and Supreme Council"]
    : ["Grados Simbólicos", "Logias Capitulares de Perfección", "Capítulos de Caballeros Rosacruz", "Areópagos de Caballeros Kadosh", "Consistorios y Supremo Consejo"];
  static String lodgeCreatedSuccess(BuildContext context) => isEn(context) ? 'The lodge has been created successfully.' : 'La logia ha sido creada correctamente.';
  static String authErrorCreateUser(BuildContext context) => isEn(context) ? 'Could not create user in authentication system.' : 'No se pudo crear el usuario en el sistema de autenticación.';
  static String userCreatedSuccessPrefix(BuildContext context) => isEn(context) ? 'The user "' : 'El usuario "';
  static String userCreatedSuccessSuffix(BuildContext context) => isEn(context) ? '" has been created. You can now assign a role.' : '" ha sido creado. Ahora puedes asignarle un rol.';
  static String assignRoleSuccess(BuildContext context) => isEn(context) ? 'The role has been assigned/updated for the user.' : 'El rol ha sido asignado/actualizado para el usuario.';
  static String profileUpdateTitlePush(BuildContext context) => isEn(context) ? 'Profile Update' : 'Actualización de tu perfil';
  static String profileUpdateBodyPushPrefix(BuildContext context) => isEn(context) ? 'Your role has been updated to ' : 'Tu rol ha sido actualizado a ';
  static String profileUpdateBodyPushIn(BuildContext context) => isEn(context) ? ' in lodge ' : ' en la logia ';
  static String noOtherProfilesMsg(BuildContext context) => isEn(context) ? 'You have no other lodge profiles to switch to.' : 'No tienes otros perfiles de logia a los que cambiar.';
  static String switchProfileTitle(BuildContext context) => isEn(context) ? 'Switch Profile' : 'Cambiar de Perfil';
  static String switchProfileLabel(BuildContext context) => isEn(context) ? 'Select Lodge/Profile' : 'Seleccionar Logia/Perfil';
  static String createNewLodgeTitle(BuildContext context) => isEn(context) ? 'Create New Lodge' : 'Crear Nueva Logia';
  static String lodgeDescriptionLabel(BuildContext context) => isEn(context) ? 'Description (Lodge Name)' : 'Descripción (Nombre de la Logia)';
  static String lodgeGroupLabel(BuildContext context) => isEn(context) ? 'Lodge Group' : 'Grupo de la Logia';
  static String selectGroupMsg(BuildContext context) => isEn(context) ? 'You must select a group' : 'Debes seleccionar un grupo';
  static String createLodgeButton(BuildContext context) => isEn(context) ? 'Create Lodge' : 'Crear Logia';
  static String assignRoleToUserTitle(BuildContext context) => isEn(context) ? 'Assign Role to User' : 'Asignar Rol a Usuario';
  static String selectUserMsg(BuildContext context) => isEn(context) ? 'Select a user' : 'Selecciona un usuario';
  static String createNewUserTitleSuper(BuildContext context) => isEn(context) ? 'Create New User' : 'Crear Nuevo Usuario';
  static String successTitle(BuildContext context) => isEn(context) ? 'Success' : 'Éxito';
  static String dbError(BuildContext context) => isEn(context) ? 'Database Error' : 'Error de Base de Datos';
  static String unknownError(BuildContext context) => isEn(context) ? 'Unknown Error' : 'Error Desconocido';
  static String userCreatedTitle(BuildContext context) => isEn(context) ? 'User Created' : 'Usuario Creado';
  static String errorCreatingUser(BuildContext context) => isEn(context) ? 'Error Creating User' : 'Error al crear usuario';
  static String assignmentSuccessTitle(BuildContext context) => isEn(context) ? 'Assignment Successful' : 'Asignación Exitosa';
  static String procedureError(BuildContext context) => isEn(context) ? 'Procedure Error' : 'Error de Procedimiento';
  static String noProfilesTitle(BuildContext context) => isEn(context) ? 'No Profiles' : 'Sin Perfiles';
  static String switchButton(BuildContext context) => isEn(context) ? 'Switch' : 'Cambiar';
  static String userLabel(BuildContext context) => isEn(context) ? 'User' : 'Usuario';
  static String logiaLabel(BuildContext context) => isEn(context) ? 'Lodge' : 'Logia';
  static String selectLodgeMsg(BuildContext context) => isEn(context) ? 'Please select a lodge' : 'Por favor selecciona una logia';
  static String selectProfileMsg(BuildContext context) => isEn(context) ? 'Please select a profile' : 'Por favor selecciona un perfil';
  static String gradoLabel(BuildContext context) => isEn(context) ? 'Degree' : 'Grado';
  static String selectGradeLabel(BuildContext context) => isEn(context) ? 'Please select a degree' : 'Por favor selecciona un grado';
  static String invalidEmailMsg(BuildContext context) => isEn(context) ? 'Invalid email format' : 'Formato de correo inválido';
  static String minCharsMsg(BuildContext context) => isEn(context) ? 'Minimum 6 characters' : 'Mínimo 6 caracteres';
  static String deleteButton(BuildContext context) => isEn(context) ? 'Delete' : 'Eliminar';
  static String cameraLabel(BuildContext context) => isEn(context) ? 'Camera' : 'Cámara';
  static String galleryLabel(BuildContext context) => isEn(context) ? 'Gallery' : 'Galería';

  static String createUserButton(BuildContext context) => isEn(context) ? 'Create User' : 'Crear Usuario';
  static String adminPlatformTitle(BuildContext context) => isEn(context) ? 'Administration Platform' : 'Plataforma de Administración';
  static String lodgesTab(BuildContext context) => isEn(context) ? 'Lodges' : 'Logias';
  static String usersTab(BuildContext context) => isEn(context) ? 'Users' : 'Usuarios';
  static String switchProfileTooltip(BuildContext context) => isEn(context) ? 'Switch to lodge profile' : 'Cambiar a perfil de logia';

  // --- Payment Report ---
  static String paymentReportTitle(BuildContext context) => isEn(context) ? 'REPORT PAYMENT' : 'REPORTAR PAGO';
  static String transferDataLabel(BuildContext context) => isEn(context) ? 'Enter your transfer details' : 'Ingresa los datos de tu transferencia';
  static String selectPendingPagoLabel(BuildContext context) => isEn(context) ? 'Select a pending payment (optional)' : 'Selecciona un pago pendiente (opcional)';
  static String pendingPagosHint(BuildContext context) => isEn(context) ? 'Generated payments not reported' : 'Pagos generados sin reportar';
  static String manualEntryLabel(BuildContext context) => isEn(context) ? 'Other (Manual Entry)' : 'Otro (Ingreso manual)';
  static String amountPaidLabel(BuildContext context) => isEn(context) ? 'Amount Paid' : 'Monto Pagado';
  static String paymentDateLabel(BuildContext context) => isEn(context) ? 'Payment Date' : 'Fecha del Pago';
  static String folioLabel(BuildContext context) => isEn(context) ? 'Folio or Tracking Code (Optional)' : 'Folio o Clave de Rastreo (Opcional)';
  static String receiptReferenceLabel(BuildContext context) => isEn(context) ? 'Receipt Reference (Optional)' : 'Referencia de la Ficha (Opcional)';
  static String receiptImageLabel(BuildContext context) => isEn(context) ? 'Receipt (Image)' : 'Comprobante (Imagen)';
  static String uploadReceiptMsg(BuildContext context) => isEn(context) ? 'Tap to upload receipt photo' : 'Toca para subir foto del comprobante';
  static String sendReportButton(BuildContext context) => isEn(context) ? 'SEND REPORT' : 'ENVIAR REPORTE';
  static String fillAllFieldsMsg(BuildContext context) => isEn(context) ? 'Please fill all fields and upload the receipt photo' : 'Por favor llena todos los campos y sube la foto del comprobante';
  static String reportSentSuccess(BuildContext context) => isEn(context) ? 'Report sent successfully. The Treasurer will validate it soon.' : 'Reporte enviado con éxito. El Tesorero lo validará pronto.';

  // --- Radio Create ---
  static String emitRadioTitle(BuildContext context) => isEn(context) ? 'Emit New Radio' : 'Emitir Nuevo Radio';
  static String generalInfoTitle(BuildContext context) => isEn(context) ? '1. General Information' : '1. Información General';
  static String radioTitleLabel(BuildContext context) => isEn(context) ? 'Radio Title' : 'Título del Radio';
  static String radioDescriptionLabel(BuildContext context) => isEn(context) ? 'Description / Message' : 'Descripción / Mensaje';
  static String configurationTitle(BuildContext context) => isEn(context) ? '2. Configuration' : '2. Configuración';
  static String periodicityLabel(BuildContext context) => isEn(context) ? 'Periodicity' : 'Periodicidad';
  static String periodicityOnce(BuildContext context) => isEn(context) ? 'Once' : 'Una sola vez';
  static String periodicityDaily(BuildContext context) => isEn(context) ? 'Daily' : 'Diario';
  static String periodicityWeekly(BuildContext context) => isEn(context) ? 'Weekly' : 'Semanal';
  static String periodicityMonthly(BuildContext context) => isEn(context) ? 'Monthly' : 'Mensual';
  static String validUntilLabel(BuildContext context) => isEn(context) ? 'Valid Until' : 'Válido hasta';
  static String selectDateOptional(BuildContext context) => isEn(context) ? 'Select date (optional)' : 'Seleccionar fecha (opcional)';
  static String targetAudienceLabel(BuildContext context) => isEn(context) ? 'Target Audience' : 'Dirigido a';
  static String audienceOwnLodge(BuildContext context) => isEn(context) ? 'My Lodge Only' : 'Solo mi Logia';
  static String audienceAllLodges(BuildContext context) => isEn(context) ? 'All Lodges Global' : 'Todas las Logias Global';
  static String audienceSubordinateLodges(BuildContext context) => isEn(context) ? 'Subordinate Lodges' : 'Logias Subordinadas';
  static String attachmentsTitle(BuildContext context) => isEn(context) ? '3. Attachments (Optional)' : '3. Adjuntos (Opcional)';
  static String uploadFileButton(BuildContext context) => isEn(context) ? 'Upload File' : 'Subir Archivo';
  static String changeFileButton(BuildContext context) => isEn(context) ? 'Change' : 'Cambiar';
  static String scanButton(BuildContext context) => isEn(context) ? 'Scan' : 'Escanear';
  static String emitRadioButton(BuildContext context) => isEn(context) ? 'EMIT RADIO' : 'EMITIR RADIO';
  static String userUuidNotFound(BuildContext context) => isEn(context) ? 'Error: User UUID not found. Please log in again.' : 'Error: No se encontró el UUID del usuario. Por favor, vuelve a iniciar sesión.';
  static String fileReadError(BuildContext context) => isEn(context) ? 'Could not read file content.' : 'No se pudo leer el contenido del archivo.';
  static String radioEmittedSuccess(BuildContext context) => isEn(context) ? 'Radio emitted and notified correctly' : 'Radio emitido y notificado correctamente';
  static String scanErrorMsg(BuildContext context) => isEn(context) ? 'Error accessing scanner: ' : 'Error al acceder al scanner: ';
  static String uploadFileError(BuildContext context) => isEn(context) ? 'Error uploading file' : 'Error al subir archivo';
  static String requiredField(BuildContext context) => isEn(context) ? 'Required' : 'Requerido';

  // --- Notifications (Static context) ---
  static String birthdayTitle() => isEnStatic() ? 'Birthday Celebration' : 'Celebración de Nacimiento';
  static String birthdayToday(String treatment, String name) => isEnStatic() 
    ? 'Today we celebrate the birth of $treatment $name' 
    : 'Hoy festejamos el nacimiento del $treatment $name';
  static String upcomingBirthdayTitle() => isEnStatic() ? 'Upcoming Birthday' : 'Próximo Nacimiento';
  static String birthdayTomorrow(String treatment, String name) => isEnStatic() 
    ? 'Tomorrow the birth of $treatment $name is celebrated' 
    : 'Mañana se celebra el nacimiento del $treatment $name';
  static String birthdayChannel() => isEnStatic() ? 'Birthday Notifications' : 'Notificaciones de Cumpleaños';
  static String birthdayChannelDesc() => isEnStatic() ? 'Channel for birthday reminders.' : 'Canal para recordatorios de cumpleaños.';
  static String generalChannel() => isEnStatic() ? 'General Notices' : 'Avisos Generales';
  static String generalChannelDesc() => isEnStatic() ? 'General app notifications' : 'Notificaciones generales de la aplicación';
  static String panicChannel() => isEnStatic() ? 'Critical Panic Alerts' : 'Alertas Críticas de Pánico';
  static String panicChannelDesc() => isEnStatic() ? 'This channel is used for vital emergency alerts.' : 'Este canal se usa para alertas de emergencia vitales.';
  static String panicAlert() => isEnStatic() ? 'PANIC ALERT!' : '¡ALERTA DE PÁNICO!';
  static String assistanceRequest() => isEnStatic() ? 'ASSISTANCE REQUEST' : 'SOLICITUD DE AUXILIO';
}
