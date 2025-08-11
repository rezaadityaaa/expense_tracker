enum MoneyType {
  cash('cash', 'Cash', '💵'),
  balance('balance', 'Saldo', '💳');

  const MoneyType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final String icon;

  static MoneyType fromString(String value) {
    return MoneyType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MoneyType.cash,
    );
  }

  @override
  String toString() => value;
}
