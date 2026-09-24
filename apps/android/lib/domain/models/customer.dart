class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;

  @override
  bool operator ==(Object other) =>
      other is Customer &&
      other.id == id &&
      other.name == name &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, name, phone);
}
