class CreditCard {
  static const tableName = 'credit_cards';

  final int? id;
  final String cardHolderName;
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final String? displayName;

  const CreditCard({
    this.id,
    required this.cardHolderName,
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    this.displayName,
  });

  CreditCard copyWith({
    int? id,
    String? cardHolderName,
    String? cardNumber,
    String? expiryDate,
    String? cvv,
    String? displayName,
  }) {
    return CreditCard(
      id: id ?? this.id,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      cardNumber: cardNumber ?? this.cardNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      cvv: cvv ?? this.cvv,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'card_holder_name': cardHolderName,
      'card_number': cardNumber,
      'expiry_date': expiryDate,
      'cvv': cvv,
      'display_name': displayName,
    }..removeWhere((key, value) => value == null);
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'] as int?,
      cardHolderName: map['card_holder_name'] as String,
      cardNumber: map['card_number'] as String,
      expiryDate: map['expiry_date'] as String,
      cvv: map['cvv'] as String,
      displayName: map['display_name'] as String?,
    );
  }
}
