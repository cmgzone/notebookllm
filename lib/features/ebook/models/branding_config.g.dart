// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branding_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BrandingConfigImpl _$$BrandingConfigImplFromJson(Map<String, dynamic> json) =>
    _$BrandingConfigImpl(
      primaryColorValue:
          (json['primaryColorValue'] as num?)?.toInt() ?? 0xFF2196F3,
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      authorName: json['authorName'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
    );

Map<String, dynamic> _$$BrandingConfigImplToJson(
        _$BrandingConfigImpl instance) =>
    <String, dynamic>{
      'primaryColorValue': instance.primaryColorValue,
      'fontFamily': instance.fontFamily,
      'authorName': instance.authorName,
      'logoUrl': instance.logoUrl,
    };
