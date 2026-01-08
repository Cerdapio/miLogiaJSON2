class PagoModel {
  int idPago;
  int idUsuario;
  double importe;
  String fecha;
  int idFormaPago;
  String folio;
  bool activo;

  PagoModel({
    required this.idPago,
    required this.idUsuario,
    required this.importe,
    required this.fecha,
    required this.idFormaPago,
    this.folio = '',
    this.activo = true,
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    return PagoModel(
      idPago: json['idPago'] ?? 0,
      idUsuario: json['idUsuario'] ?? 0,
      importe: json['importe']?.toDouble() ?? 0.0,
      fecha: json['fecha'] ?? '',
      idFormaPago: json['idFormaPago'] ?? 0,
      folio: json['folio'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idPago': idPago,
      'idUsuario': idUsuario,
      'importe': importe,
      'fecha': fecha,
      'idFormaPago': idFormaPago,
      'folio': folio,
      'activo': activo,
    };
  }
}
