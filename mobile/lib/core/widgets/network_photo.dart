import 'package:material_ui/material_ui.dart';

/// A photo from the API, with a neutral placeholder while it loads, when it
/// fails and when there is no photo at all.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    required this.url,
    required this.semanticLabel,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final String? url;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
    final address = url;

    if (address == null) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        address,
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: ExcludeSemantics(
        child: Icon(Icons.restaurant_outlined, color: scheme.outline),
      ),
    );
  }
}
