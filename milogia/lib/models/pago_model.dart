class PagoModel {
  int idPago;
  int idUsuario;
  double importe;
  String fecha;
  int idFormaPago;
  String folio;
  bool activo;
  String estatus;

  PagoModel({
    required this.idPago,
    required this.idUsuario,
    required this.importe,
    required this.fecha,
    required this.idFormaPago,
    this.folio = '',
    this.activo = true,
    this.estatus = 'Pendiente',
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    return PagoModel(
      idPago: json['idPago'] ?? 0,
      idUsuario: json['idUsuario'] ?? 0,
      importe: (json['importe'] ?? json['Importe'] ?? 0).toDouble(),
      fecha: json['fecha'] ?? json['Fecha'] ?? '',
      idFormaPago: json['idFormaPago'] ?? 0,
      folio: json['folio'] ?? json['Folio'] ?? '',
      activo: json['activo'] ?? json['Activo'] ?? true,
      estatus: json['estatus'] ?? json['Estatus'] ?? 'Pendiente',
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
      'estatus': estatus,
    };
  }
}
