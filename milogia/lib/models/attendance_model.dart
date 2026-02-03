
enum AttendanceStatus {
  absent,        // 0: X
  present,       // 1: ✓
  justified,     // 2: J
  notApplicable, // 3: -
}

class SessionAttendance {
  final int? idSession;
  final int iddLogia;
  final DateTime fecha;
  final String tipo; // 'TO', 'TE', 'NA'
  final double hospitalario;
  final int trabajos;

  SessionAttendance({
    this.idSession,
    required this.iddLogia,
    required this.fecha,
    required this.tipo,
    this.hospitalario = 0.0,
    this.trabajos = 0,
  });

  factory SessionAttendance.fromJson(Map<String, dynamic> json) {
    return SessionAttendance(
      idSession: json['idSession'],
      iddLogia: json['iddLogia'],
      fecha: DateTime.parse(json['Fecha']),
      tipo: json['Tipo'] ?? 'TO',
      hospitalario: (json['Hospitalario'] ?? 0.0).toDouble(),
      trabajos: json['Trabajos'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idSession != null) 'idSession': idSession,
      'iddLogia': iddLogia,
      'Fecha': fecha.toIso8601String().substring(0, 10),
      'Tipo': tipo,
      'Hospitalario': hospitalario,
      'Trabajos': trabajos,
    };
  }
}

class MemberAttendance {
  final int? idAsistencia;
  final int idSession;
  final int idUsuario;
  final AttendanceStatus estado;

  MemberAttendance({
    this.idAsistencia,
    required this.idSession,
    required this.idUsuario,
    required this.estado,
  });

  factory MemberAttendance.fromJson(Map<String, dynamic> json) {
    return MemberAttendance(
      idAsistencia: json['idAsistencia'],
      idSession: json['idSession'],
      idUsuario: json['idUsuario'],
      estado: AttendanceStatus.values[json['Estado'] ?? 0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idAsistencia != null) 'idAsistencia': idAsistencia,
      'idSession': idSession,
      'idUsuario': idUsuario,
      'Estado': estado.index,
    };
  }
}

class UserAttendanceStats {
  final int idUsuario;
  final String nombre;
  final int totalSesionesLeCorrespondian;
  final int totalAsistencias;
  final int totalFaltas;
  final int totalJustificadas;

  UserAttendanceStats({
    required this.idUsuario,
    required this.nombre,
    required this.totalSesionesLeCorrespondian,
    required this.totalAsistencias,
    required this.totalFaltas,
    required this.totalJustificadas,
  });

  double get percentage => totalSesionesLeCorrespondian == 0 ? 0 : (totalAsistencias / totalSesionesLeCorrespondian) * 100;
}
