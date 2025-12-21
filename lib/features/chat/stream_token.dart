import 'package:freezed_annotation/freezed_annotation.dart';

part 'stream_token.freezed.dart';

@freezed
class StreamToken with _$StreamToken {
  const factory StreamToken.text({required String text}) = _Text;
  const factory StreamToken.citation({required String id, required String snippet}) = _Citation;
  const factory StreamToken.done() = _Done;
}