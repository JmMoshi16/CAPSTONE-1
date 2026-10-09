import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Guarantees a [min] x [min] touch area without changing how the child is laid out:
/// the child gets exactly the parent's constraints (so a card in a grid still fills its
/// cell), and only when it comes out smaller than [min] is the box grown and the child
/// centred in it (so a 20 dp icon gets a 48 dp target).
class MinTapArea extends SingleChildRenderObjectWidget {
  const MinTapArea({super.key, this.min = 48, super.child});

  final double min;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMinTapArea(min);

  @override
  void updateRenderObject(BuildContext context, RenderMinTapArea renderObject) => renderObject.min = min;
}

class RenderMinTapArea extends RenderShiftedBox {
  RenderMinTapArea(this._min) : super(null);

  double _min;
  set min(double v) {
    if (v == _min) return;
    _min = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(_min, _min));
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(Size(math.max(child.size.width, _min), math.max(child.size.height, _min)));
    (child.parentData! as BoxParentData).offset =
        Offset((size.width - child.size.width) / 2, (size.height - child.size.height) / 2);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(super.computeMinIntrinsicWidth(height), _min);
  @override
  double computeMaxIntrinsicWidth(double height) => math.max(super.computeMaxIntrinsicWidth(height), _min);
  @override
  double computeMinIntrinsicHeight(double width) => math.max(super.computeMinIntrinsicHeight(width), _min);
  @override
  double computeMaxIntrinsicHeight(double width) => math.max(super.computeMaxIntrinsicHeight(width), _min);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child?.getDryLayout(constraints) ?? Size.zero;
    return constraints.constrain(Size(math.max(c.width, _min), math.max(c.height, _min)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The whole grown area counts as a hit, not only the child's own rectangle.
    if (!size.contains(position)) return false;
    if (child != null) hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
