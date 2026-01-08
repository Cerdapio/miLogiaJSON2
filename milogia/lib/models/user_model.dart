import 'dart:convert';
import 'dart:io';

class RootModel {
  User user;
  String status;
  String message;
  Catalogos catalogos;

  RootModel({
    required this.user,
    required this.status,
    required this.message,
    required this.catalogos,
  });

  factory RootModel.fromJson(Map<String, dynamic> json) => RootModel(
        user: User.fromJson(json['user'] ?? {}),
        status: json['status'] ?? '',
        message: json['message'] ?? '',
        catalogos: Catalogos.fromJson(json['catalogos'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'status': status,
        'message': message,
        'catalogos': catalogos.toJson(),
      };

  static Future<RootModel> fromFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    return RootModel.fromJson(json.decode(content));
  }

  Future<void> saveToFile(String path) async {
    final file = File(path);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(toJson()));
  }
}

class User {
  String Foto;
  List<Pago> pagos;
  String Nombre;
  String Usuario;
  String Telefono;
  String Direccion;
  int idUsuario;
  List<Documento> documentos;
  String Contrasena; // mapea "Contraseña"
  String FechaNacimiento;
  String CorreoElectronico;
  List<PerfilOpcion> perfiles_opciones;
  List<ContactoEmergencia> contactosEmergencia;

  User({
    required this.Foto,
    required this.pagos,
    required this.Nombre,
    required this.Usuario,
    required this.Telefono,
    required this.Direccion,
    required this.idUsuario,
    required this.documentos,
    required this.Contrasena,
    required this.FechaNacimiento,
    required this.CorreoElectronico,
    required this.perfiles_opciones,
    required this.contactosEmergencia,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        Foto: json['Foto'] ?? '',
        pagos: (json['pagos'] as List<dynamic>? ?? []).map((e) => Pago.fromJson(e)).toList(),
        Nombre: json['Nombre'] ?? '',
        Usuario: json['Usuario'] ?? '',
        Telefono: json['Telefono'] ?? '',
        Direccion: json['Direccion'] ?? '',
        idUsuario: json['idUsuario'] ?? 0,
        documentos: (json['documentos'] as List<dynamic>? ?? []).map((e) => Documento.fromJson(e)).toList(),
        Contrasena: json['Contraseña'] ?? '',
        FechaNacimiento: json['FechaNacimiento'] ?? '',
        CorreoElectronico: json['CorreoElectronico'] ?? '',
        perfiles_opciones: (json['perfiles_opciones'] as List<dynamic>? ?? []).map((e) => PerfilOpcion.fromJson(e)).toList(),
        contactosEmergencia: (json['contactosEmergencia'] as List<dynamic>? ?? []).map((e) => ContactoEmergencia.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'Foto': Foto,
        'pagos': pagos.map((e) => e.toJson()).toList(),
        'Nombre': Nombre,
        'Usuario': Usuario,
        'Telefono': Telefono,
        'Direccion': Direccion,
        'idUsuario': idUsuario,
        'documentos': documentos.map((e) => e.toJson()).toList(),
        'Contraseña': Contrasena,
        'FechaNacimiento': FechaNacimiento,
        'CorreoElectronico': CorreoElectronico,
        'perfiles_opciones': perfiles_opciones.map((e) => e.toJson()).toList(),
        'contactosEmergencia': contactosEmergencia.map((e) => e.toJson()).toList(),
      };
void updateFromJson(Map<String, dynamic> json) {
    if (json.containsKey('Telefono')) {
      this.Telefono = json['Telefono'] as String;
    }
    if (json.containsKey('FechaNacimiento')) {
      this.FechaNacimiento = json['FechaNacimiento'] as String;
    }
    if (json.containsKey('Direccion')) {
      this.Direccion = json['Direccion'] as String;
    }
    if (json.containsKey('CorreoElectronico')) {
      this.CorreoElectronico = json['CorreoElectronico'] as String;
    }
    // Opcional: Si el campo 'Usuario' también se actualizó o se devuelve
    // Se recomienda actualizarlo si su valor puede cambiar.
    if (json.containsKey('Usuario')) {
      this.Usuario = json['Usuario'] as String;
    }
    // Si la actualización incluyó una nueva Foto, también debes actualizarla
    if (json.containsKey('Foto')) {
      this.Foto = json['Foto'] as String;
    }
    // Nota: Las demás listas (pagos, documentos, contactosEmergencia, etc.) 
    // no se actualizaron en la llamada a la base de datos, por lo que no es necesario
    // incluirlas aquí, a menos que Supabase las devuelva de forma implícita.
  }
}
class Pago {
  double Costo;
  String Fecha;
  String Folio;
  int idPago;
  int idFormaPago;
  double Importe;
  int Cantidad;
  int iddLogia;
  String Descripcion;

  Pago({
    required this.Costo,
    required this.Fecha,
    required this.Folio,
    required this.idPago,
    required this.idFormaPago,
    required this.Importe,
    required this.Cantidad,
    required this.iddLogia,
    required this.Descripcion,
  });

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
        Costo: (json['Costo'] ?? 0).toDouble(),
        Fecha: json['Fecha'] ?? '',
        Folio: json['Folio'] ?? '',
        idPago: json['idPago'] ?? 0,
        idFormaPago: json['idFormaPago'] ?? 0,
        Importe: (json['Importe'] ?? 0).toDouble(),
        Cantidad: json['Cantidad'] ?? 0,
        iddLogia: json['iddLogia'] ?? 0,
        Descripcion: json['Descripcion'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'Costo': Costo,
        'Fecha': Fecha,
        'Folio': Folio,
        'idPago': idPago,
        'idFormaPago': idFormaPago,
        'Importe': Importe,
        'Cantidad': Cantidad,
        'iddLogia': iddLogia,
        'Descripcion': Descripcion,
      };
}

class Documento {
  String Fecha;
  String Descripcion;
  String NombreCorto;
  int idGrado;
  int iddLogia;
  String NombreLargo;

  Documento({
    required this.Fecha,
    required this.Descripcion,
    required this.NombreCorto,
    required this.idGrado,
    required this.iddLogia,
    required this.NombreLargo,
  });

  factory Documento.fromJson(Map<String, dynamic> json) => Documento(
        Fecha: json['Fecha'] ?? '',
        Descripcion: json['Descripcion'] ?? '',
        NombreCorto: json['NombreCorto'] ?? '',
        idGrado: json['idGrado'] ?? '',
        iddLogia: json['iddLogia'] ?? '',
        NombreLargo: json['NombreLargo'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'Fecha': Fecha,
        'Descripcion': Descripcion,
        'NombreCorto': NombreCorto,
        'idGrado': idGrado,
        'iddLogia': iddLogia,
        'NombreLargo': NombreLargo,
      };
}

class PerfilOpcion {
  String Grupo;
  Colores colores;
  int idGrado;
  int idLogia;
  int idPerfil;
  List<int> permisos;
  String Abreviatura;
  String GradoNombre;
  String LogiaNombre;
  String Significado;
  String Tratamiento;
  String PerfilNombre;

  PerfilOpcion({
    required this.Grupo,
    required this.colores,
    required this.idGrado,
    required this.idLogia,
    required this.idPerfil,
    required this.permisos,
    required this.Abreviatura,
    required this.GradoNombre,
    required this.LogiaNombre,
    required this.Significado,
    required this.Tratamiento,
    required this.PerfilNombre,
  });

  factory PerfilOpcion.fromJson(Map<String, dynamic> json) => PerfilOpcion(
        Grupo: json['Grupo'] ?? '',
        colores: Colores.fromJson(json['colores'] ?? {}),
        idGrado: json['idGrado'] ?? 0,
        idLogia: json['idLogia'] ?? 0,
        idPerfil: json['idPerfil'] ?? 0,
        permisos: (json['permisos'] as List<dynamic>? ?? []).map((e) => (e ?? 0) as int).toList(),
        Abreviatura: json['Abreviatura'] ?? '',
        GradoNombre: json['GradoNombre'] ?? '',
        LogiaNombre: json['LogiaNombre'] ?? '',
        Significado: json['Significado'] ?? '',
        Tratamiento: json['Tratamiento'] ?? '',
        PerfilNombre: json['PerfilNombre'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'Grupo': Grupo,
        'colores': colores.toJson(),
        'idGrado': idGrado,
        'idLogia': idLogia,
        'idPerfil': idPerfil,
        'permisos': permisos,
        'Abreviatura': Abreviatura,
        'GradoNombre': GradoNombre,
        'LogiaNombre': LogiaNombre,
        'Significado': Significado,
        'Tratamiento': Tratamiento,
        'PerfilNombre': PerfilNombre,
      };

      
}

class Colores {
  String C1;
  String C2;
  String C3;
  String C4;

  Colores({required this.C1, required this.C2, required this.C3, required this.C4});

  factory Colores.fromJson(Map<String, dynamic> json) => Colores(
        C1: json['C1'] ?? '',
        C2: json['C2'] ?? '',
        C3: json['C3'] ?? '',
        C4: json['C4'] ?? '',
      );

  Map<String, dynamic> toJson() => {'C1': C1, 'C2': C2, 'C3': C3, 'C4': C4};
}

class ContactoEmergencia {
  String Nombre;
  String Telefono;
  String Direccion;
  int idUsuario;
  int Porcentaje;
  bool Beneficiario;
  int idEmergencia;
  int idParentezco;

  ContactoEmergencia({
    required this.Nombre,
    required this.Telefono,
    required this.Direccion,
    required this.idUsuario,
    required this.Porcentaje,
    required this.Beneficiario,
    required this.idEmergencia,
    required this.idParentezco,
  });

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) => ContactoEmergencia(
        Nombre: json['Nombre'] ?? '',
        Telefono: json['Telefono'] ?? '',
        Direccion: json['Direccion'] ?? '',
        idUsuario: json['idUsuario'] ?? 0,
        Porcentaje: json['Porcentaje'] ?? 0,
        Beneficiario: json['Beneficiario'] ?? false,
        idEmergencia: json['idEmergencia'] ?? 0,
        idParentezco: json['idParentezco'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'Nombre': Nombre,
        'Telefono': Telefono,
        'Direccion': Direccion,
        'idUsuario': idUsuario,
        'Porcentaje': Porcentaje,
        'Beneficiario': Beneficiario,
        'idEmergencia': idEmergencia,
        'idParentezco': idParentezco,
      };
}

/* Catalogos y submodelos */
class Catalogos {
  List<Parentezco> parentezcos;
  List<ConceptoCatalogo> conceptos_catalogo;
  List<DocumentosCatalogo> documentos_catalogo;
  List<ListaLogiasPorUsuario> listaLogiasPorUsuario;

  Catalogos({
    required this.parentezcos,
    required this.conceptos_catalogo,
    required this.documentos_catalogo,
    required this.listaLogiasPorUsuario,
  });

  factory Catalogos.fromJson(Map<String, dynamic> json) => Catalogos(
        parentezcos: (json['parentezcos'] as List<dynamic>? ?? []).map((e) => Parentezco.fromJson(e)).toList(),
        conceptos_catalogo: (json['conceptos_catalogo'] as List<dynamic>? ?? []).map((e) => ConceptoCatalogo.fromJson(e)).toList(),
        documentos_catalogo: (json['documentos_catalogo'] as List<dynamic>? ?? []).map((e) => DocumentosCatalogo.fromJson(e)).toList(),
        listaLogiasPorUsuario: (json['listaLogiasPorUsuario'] as List<dynamic>? ?? []).map((e) => ListaLogiasPorUsuario.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'parentezcos': parentezcos.map((e) => e.toJson()).toList(),
        'conceptos_catalogo': conceptos_catalogo.map((e) => e.toJson()).toList(),
        'documentos_catalogo': documentos_catalogo.map((e) => e.toJson()).toList(),
        'listaLogiasPorUsuario': listaLogiasPorUsuario.map((e) => e.toJson()).toList(),
      };
}

class Parentezco {
  String Descripcion;
  int idParentezco;

  Parentezco({required this.Descripcion, required this.idParentezco});

  factory Parentezco.fromJson(Map<String, dynamic> json) => Parentezco(
        Descripcion: json['Descripcion'] ?? '',
        idParentezco: json['idParentezco'] ?? 0,
      );

  Map<String, dynamic> toJson() => {'Descripcion': Descripcion, 'idParentezco': idParentezco};
}

class ConceptoCatalogo {
  List<ConceptoDetalle> detalles;
  int idConcepto;
  String Descripcion;
  bool RequierePago;
  bool RequiereGrado;

  ConceptoCatalogo({
    required this.detalles,
    required this.idConcepto,
    required this.Descripcion,
    required this.RequierePago,
    required this.RequiereGrado,
  });

  factory ConceptoCatalogo.fromJson(Map<String, dynamic> json) => ConceptoCatalogo(
        detalles: (json['detalles'] as List<dynamic>? ?? []).map((e) => ConceptoDetalle.fromJson(e)).toList(),
        idConcepto: json['idConcepto'] ?? 0,
        Descripcion: json['Descripcion'] ?? '',
        RequierePago: json['RequierePago'] ?? false,
        RequiereGrado: json['RequiereGrado'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'detalles': detalles.map((e) => e.toJson()).toList(),
        'idConcepto': idConcepto,
        'Descripcion': Descripcion,
        'RequierePago': RequierePago,
        'RequiereGrado': RequiereGrado,
      };
}

class ConceptoDetalle {
  double Costo;
  int idGrado;
  String ctaBanco;
  int iddLogia;
  int iddConcepto;

  ConceptoDetalle({
    required this.Costo,
    required this.idGrado,
    required this.ctaBanco,
    required this.iddLogia,
    required this.iddConcepto,
  });

  factory ConceptoDetalle.fromJson(Map<String, dynamic> json) => ConceptoDetalle(
        Costo: (json['Costo'] ?? 0).toDouble(),
        idGrado: json['idGrado'] ?? 0,
        ctaBanco: json['ctaBanco'] ?? "",
        iddLogia: json['iddLogia'] ?? 0,
        iddConcepto: json['iddConcepto'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'Costo': Costo,
        'idGrado': idGrado,
        'ctaBanco': ctaBanco,
        'iddLogia': iddLogia,
        'iddConcepto': iddConcepto,
      };

  void operator [](String other) {}
}

class DocumentosCatalogo {
  bool Registro;
  List<DocumentosCatalogoDetalle> detalles;
  bool Solicitud;
  String Descripcion;
  bool Elavoracion; // Nota: Se mantiene "Elavoracion" tal cual viene en el JSON
  int idDocumento;
  bool RequierePago;
  bool RequiereGrado;
  bool RequiereDescripcion;

  DocumentosCatalogo({
    required this.Registro,
    required this.detalles,
    required this.Solicitud,
    required this.Descripcion,
    required this.Elavoracion,
    required this.idDocumento,
    required this.RequierePago,
    required this.RequiereGrado,
    required this.RequiereDescripcion,
  });

  factory DocumentosCatalogo.fromJson(Map<String, dynamic> json) => DocumentosCatalogo(
        Registro: json['Registro'] ?? false,
        detalles: (json['detalles'] as List<dynamic>? ?? [])
            .map((e) => DocumentosCatalogoDetalle.fromJson(e))
            .toList(),
        Solicitud: json['Solicitud'] ?? false,
        Descripcion: json['Descripcion'] ?? '',
        Elavoracion: json['Elavoracion'] ?? false,
        idDocumento: json['idDocumento'] ?? 0,
        RequierePago: json['RequierePago'] ?? false,
        RequiereGrado: json['RequiereGrado'] ?? false,
        RequiereDescripcion: json['RequiereDescripcion'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'Registro': Registro,
        'detalles': detalles.map((e) => e.toJson()).toList(),
        'Solicitud': Solicitud,
        'Descripcion': Descripcion,
        'Elavoracion': Elavoracion,
        'idDocumento': idDocumento,
        'RequierePago': RequierePago,
        'RequiereGrado': RequiereGrado,
        'RequiereDescripcion': RequiereDescripcion,
      };
}

class DocumentosCatalogoDetalle {
  int Grado;
  String NombreCorto;
  String NombreLargo;
  int idConcepto;

  DocumentosCatalogoDetalle({
    required this.Grado,
    required this.NombreCorto,
    required this.NombreLargo,
    required this.idConcepto,
  });

  factory DocumentosCatalogoDetalle.fromJson(Map<String, dynamic> json) =>
      DocumentosCatalogoDetalle(
        Grado: json['Grado'] ?? 0,
        NombreCorto: json['NombreCorto'] ?? '',
        NombreLargo: json['NombreLargo'] ?? '',
        idConcepto: json['idConcepto'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'Grado': Grado,
        'NombreCorto': NombreCorto,
        'NombreLargo': NombreLargo,
        'idConcepto': idConcepto,
      };
}

class ListaLogiasPorUsuario {
  String Nombre;
  int idUsuario;
  List<int> listaIddLogia;

  ListaLogiasPorUsuario({required this.Nombre, required this.idUsuario, required this.listaIddLogia});

  factory ListaLogiasPorUsuario.fromJson(Map<String, dynamic> json) => ListaLogiasPorUsuario(
        Nombre: json['Nombre'] ?? '',
        idUsuario: json['idUsuario'] ?? 0,
        listaIddLogia: (json['listaIddLogia'] as List<dynamic>? ?? []).map((e) => (e ?? 0) as int).toList(),
      );

  Map<String, dynamic> toJson() => {'Nombre': Nombre, 'idUsuario': idUsuario, 'listaIddLogia': listaIddLogia};
}