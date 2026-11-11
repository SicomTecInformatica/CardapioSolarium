int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ??
        double.tryParse(value.trim())?.toInt() ??
        0;
  }
  return 0;
}

double asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

String asString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == 'true' || text == '1';
  }
  return false;
}

Map<String, dynamic> asMap(dynamic json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return Map<String, dynamic>.from(json);
  return <String, dynamic>{};
}
