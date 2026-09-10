/// 极简 m3u8 解析器（满足直播 HLS 录制）：支持 master playlist 选流、
/// media playlist 分片解析、MEDIA-SEQUENCE、ENDLIST、加密检测。
class HlsVariant {
  final String url;
  final int bandwidth;
  final String? resolution;
  HlsVariant({required this.url, required this.bandwidth, this.resolution});
}

class HlsSegment {
  final String seq; // MEDIA-SEQUENCE + index，作为分片唯一 ID（可续传）
  final String url;
  final double duration;
  HlsSegment({required this.seq, required this.url, required this.duration});
}

class HlsPlaylist {
  final List<HlsVariant> variants;
  final List<HlsSegment> segments;
  final bool endList;
  final bool encrypted;
  final String keyMethod;

  bool get isMaster => variants.isNotEmpty;

  HlsPlaylist({
    required this.variants,
    required this.segments,
    required this.endList,
    required this.encrypted,
    required this.keyMethod,
  });
}

class HlsParser {
  static HlsPlaylist parse(String content, String baseUrl) {
    final lines = content.split(RegExp(r'\r?\n'));
    final variants = <HlsVariant>[];
    final segments = <HlsSegment>[];
    var mediaSequence = 0;
    var endList = false;
    var encrypted = false;
    var keyMethod = "";
    String? pendingVariantUrl;
    int? pendingVariantBandwidth;
    String? pendingVariantResolution;
    double pendingDuration = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith("#EXTM3U")) {
        continue;
      }
      if (line.startsWith("#EXT-X-STREAM-INF")) {
        pendingVariantBandwidth = _attrInt(line, "BANDWIDTH");
        pendingVariantResolution = _attrString(line, "RESOLUTION");
        continue;
      }
      if (line.startsWith("#EXT-X-MEDIA-SEQUENCE")) {
        mediaSequence = int.tryParse(line.split(":").last.trim()) ?? 0;
        continue;
      }
      if (line.startsWith("#EXT-X-TARGETDURATION")) continue;
      if (line.startsWith("#EXT-X-ENDLIST")) {
        endList = true;
        continue;
      }
      if (line.startsWith("#EXT-X-KEY")) {
        final method = _attrString(line, "METHOD") ?? "NONE";
        keyMethod = method;
        encrypted = method.toUpperCase() != "NONE";
        continue;
      }
      if (line.startsWith("#EXTINF")) {
        pendingDuration =
            double.tryParse(line.split(":").last.split(",").first) ?? 0;
        continue;
      }
      if (line.startsWith("#")) continue;

      final url = _resolve(baseUrl, line);
      if (pendingVariantBandwidth != null) {
        variants.add(HlsVariant(
          url: url,
          bandwidth: pendingVariantBandwidth,
          resolution: pendingVariantResolution,
        ));
        pendingVariantBandwidth = null;
        pendingVariantResolution = null;
      } else {
        final seq = (mediaSequence + segments.length).toString();
        segments.add(
            HlsSegment(seq: seq, url: url, duration: pendingDuration));
        pendingDuration = 0;
      }
    }

    return HlsPlaylist(
      variants: variants,
      segments: segments,
      endList: endList,
      encrypted: encrypted,
      keyMethod: keyMethod,
    );
  }

  static int? _attrInt(String line, String name) {
    final v = _attrString(line, name);
    return v == null ? null : int.tryParse(v);
  }

  static String? _attrString(String line, String name) {
    final m = RegExp('$name=([^,]+)').firstMatch(line);
    return m?.group(1)?.trim().replaceAll('"', '');
  }

  static String _resolve(String baseUrl, String ref) {
    try {
      final base = Uri.parse(baseUrl);
      return base.resolveUri(Uri.parse(ref)).toString();
    } catch (_) {
      return ref;
    }
  }
}