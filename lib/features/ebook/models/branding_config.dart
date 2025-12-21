import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'branding_config.freezed.dart';
part 'branding_config.g.dart';

@freezed
class BrandingConfig with _$BrandingConfig {
  const factory BrandingConfig({
    @Default(0xFF2196F3) int primaryColorValue, // Store int for serialization
    @Default('Roboto') String fontFamily,
    @Default('') String authorName,
    String? logoUrl,
  }) = _BrandingConfig;

  const BrandingConfig._();

  factory BrandingConfig.fromBackendJson(Map<String, dynamic> json) =>
      BrandingConfig(
        primaryColorValue: json['primary_color_value'] ?? 0xFF2196F3,
        fontFamily: json['font_family'] ?? 'Roboto',
        authorName: json['author_name'] ?? '',
        logoUrl: json['logo_url'],
      );

  Map<String, dynamic> toBackendJson() => {
        'primary_color_value': primaryColorValue,
        'font_family': fontFamily,
        'author_name': authorName,
        'logo_url': logoUrl,
      };

  factory BrandingConfig.fromJson(Map<String, dynamic> json) =>
      _$BrandingConfigFromJson(json);
}

extension BrandingConfigX on BrandingConfig {
  Color get primaryColor => Color(primaryColorValue);
}
