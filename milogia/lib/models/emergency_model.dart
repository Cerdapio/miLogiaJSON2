// ...existing code...
class EmergencyModel {
  int idEmergencia;
  int idUsuario;
  int idParentezco;
  String nombre;
  String telefono;
  String direccion;
  int porcentaje; // 0..100
  bool beneficiario; // true => beneficiario activo
  String activo; // '1' o '0' (si tu tabla lo usa)

  EmergencyModel({
    required this.idEmergencia,
    required this.idUsuario,
    required this.idParentezco,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.porcentaje,
    required this.beneficiario,
    this.activo = '1',
  });

  factory EmergencyModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true' || s == 't' || s == 'yes';
    }

    return EmergencyModel(
      idEmergencia: parseInt(json['idEmergencia'] ?? json['id_emergencia'] ?? 0),
      idUsuario: parseInt(json['idUsuario'] ?? json['id_usuario'] ?? 0),
      idParentezco: parseInt(json['idParentezco'] ?? json['id_parentezco'] ?? 0),
      nombre: (json['Nombre'] ?? json['nombre'] ?? '').toString(),
      telefono: (json['Telefono'] ?? json['telefono'] ?? '').toString(),
      direccion: (json['Direccion'] ?? json['direccion'] ?? '').toString(),
      porcentaje: parseInt(json['Porcentaje'] ?? json['porcentaje'] ?? 0),
      beneficiario: parseBool(json['Beneficiario'] ?? json['beneficiario'] ?? 0),
      activo: (json['Activo'] ?? json['activo'] ?? '1').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idEmergencia': idEmergencia,
      'idUsuario': idUsuario,
      'idParentezco': idParentezco,
      'Nombre': nombre,
      'Telefono': telefono,
      'Direccion': direccion,
      'Porcentaje': porcentaje,
      'Beneficiario': beneficiario ? 1 : 0,
      'Activo': activo,
    };
  }

  EmergencyModel copyWith({
    int? idEmergencia,
    int? idUsuario,
    int? idParentezco,
    String? nombre,
    String? telefono,
    String? direccion,
    int? porcentaje,
    bool? beneficiario,
    String? activo,
  }) {
    return EmergencyModel(
      idEmergencia: idEmergencia ?? this.idEmergencia,
      idUsuario: idUsuario ?? this.idUsuario,
      idParentezco: idParentezco ?? this.idParentezco,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      porcentaje: porcentaje ?? this.porcentaje,
      beneficiario: beneficiario ?? this.beneficiario,
      activo: activo ?? this.activo,
    );
  }
}
