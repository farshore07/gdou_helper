class ElectricityBill {
  final String id;
  final double balance; // 当前余额
  final double totalUsage; // 总用电量 (度)
  final DateTime updateTime;

  const ElectricityBill({
    required this.id,
    required this.balance,
    this.totalUsage = 0,
    required this.updateTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'balance': balance,
        'totalUsage': totalUsage,
        'updateTime': updateTime.millisecondsSinceEpoch,
      };

  factory ElectricityBill.fromJson(Map<String, dynamic> json) => ElectricityBill(
        id: json['id'] as String,
        balance: (json['balance'] as num).toDouble(),
        totalUsage: (json['totalUsage'] as num?)?.toDouble() ?? 0,
        updateTime:
            DateTime.fromMillisecondsSinceEpoch(json['updateTime'] as int),
      );

  ElectricityBill copyWith({
    String? id,
    double? balance,
    double? totalUsage,
    DateTime? updateTime,
  }) =>
      ElectricityBill(
        id: id ?? this.id,
        balance: balance ?? this.balance,
        totalUsage: totalUsage ?? this.totalUsage,
        updateTime: updateTime ?? this.updateTime,
      );
}
