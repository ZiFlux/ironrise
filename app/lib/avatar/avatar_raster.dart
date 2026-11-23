import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Кэш готовых картинок героя. Художник аватара тяжёлый (размытия, градиенты,
/// десятки контуров), а неподвижный герой одинаков от кадра к кадру: рисуем его
/// один раз в картинку и дальше только выводим её. Так магазин с десятками
/// превью, пять соперников в дуэлях и переходы между вкладками не тормозят.
class AvatarRaster {
  AvatarRaster._();

  static final _cache = <Object, ui.Image>{};
  static int _bytes = 0;

  /// Сколько памяти держим под картинки: ~40 МБ — это десятки превью и пара больших героев.
  static const maxBytes = 40 << 20;

  /// Картинка для [key] размера [size] при плотности [dpr]; нет в кэше — рисуется.
  /// Возвращает собственную копию (clone), которую вызывающий обязан освободить.
  static ui.Image take(
    Object key,
    Size size,
    double dpr,
    void Function(Canvas canvas, Size size) paint,
  ) {
    final full = (key, size.width.round(), size.height.round(), dpr);
    final hit = _cache.remove(full);
    if (hit != null) {
      _cache[full] = hit; // свежий — в конец очереди
      return hit.clone();
    }
    final w = (size.width * dpr).ceil().clamp(1, 4096);
    final h = (size.height * dpr).ceil().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    _cache[full] = image;
    _bytes += w * h * 4;
    while (_bytes > maxBytes && _cache.length > 1) {
      final oldest = _cache.keys.first;
      final img = _cache.remove(oldest)!;
      _bytes -= img.width * img.height * 4;
      img.dispose(); // у показанных копий своя ссылка — они не пропадут
    }
    return image.clone();
  }
}

/// Рисунок через кэш [AvatarRaster]: [cacheKey] описывает всё, от чего зависит
/// картинка (образ, уровни, поза), [paint] рисует её при промахе. Занимает всё
/// данное место, как CustomPaint с Size.infinite.
class RasterPaint extends LeafRenderObjectWidget {
  const RasterPaint({super.key, required this.cacheKey, required this.paint});

  final Object cacheKey;
  final void Function(Canvas canvas, Size size) paint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRaster(cacheKey, paint, MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderRaster).update(
        cacheKey,
        paint,
        MediaQuery.devicePixelRatioOf(context),
      );
}

class _RenderRaster extends RenderBox {
  _RenderRaster(this._key, this._paint, this._dpr);

  Object _key;
  void Function(Canvas canvas, Size size) _paint;
  double _dpr;
  ui.Image? _image;
  Object? _for;

  void update(Object key, void Function(Canvas, Size) paint, double dpr) {
    _paint = paint;
    if (key != _key || dpr != _dpr) {
      _key = key;
      _dpr = dpr;
      markNeedsPaint();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final want = (_key, size, _dpr);
    if (_image == null || _for != want) {
      _image?.dispose();
      _image = AvatarRaster.take(_key, size, _dpr, _paint);
      _for = want;
    }
    final img = _image!;
    context.canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      offset & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
