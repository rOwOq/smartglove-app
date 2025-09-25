import 'dart:async';
import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';

/// targetLevel: 0.0 ~ 1.0 사이의 값
/// 1초 뒤에 2초 동안 0→targetLevel 로 부드럽게 채워집니다.
class BatteryIndicator extends StatefulWidget {
  final double targetLevel;
  final double width;
  final double height;
  const BatteryIndicator({
    Key? key,
    required this.targetLevel,
    this.width = 80,
    this.height = 180,
  }) : super(key: key);

  @override
  _BatteryIndicatorState createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  double _animatedLevel = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1초 뒤 애니메이션 시작
    Future.delayed(const Duration(seconds: 1), _start);
  }

  void _start() {
    const total = Duration(seconds: 2);
    const tick  = Duration(milliseconds: 50);
    final steps     = (total.inMilliseconds / tick.inMilliseconds).round();
    final increment = steps > 0 ? widget.targetLevel / steps : widget.targetLevel;

    _timer?.cancel();
    _timer = Timer.periodic(tick, (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _animatedLevel = (_animatedLevel + increment).clamp(0.0, widget.targetLevel);
        if (_animatedLevel >= widget.targetLevel) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          LiquidLinearProgressIndicator(
            value: _animatedLevel,
            valueColor: AlwaysStoppedAnimation(const Color(0xFFA3F3EB)),
            backgroundColor: Colors.grey.shade200,
            borderColor: Colors.blueGrey,
            borderWidth: 2.0,
            borderRadius: 12.0,
            direction: Axis.vertical,
          ),
          // 중앙 퍼센트 텍스트
          Positioned.fill(
            child: Center(
              child: Text(
                '${(_animatedLevel * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
