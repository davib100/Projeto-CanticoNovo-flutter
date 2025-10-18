// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchStateImpl _$$SearchStateImplFromJson(Map<String, dynamic> json) =>
    _$SearchStateImpl(
      query: json['query'] as String? ?? '',
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isLoading: json['isLoading'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
    );

Map<String, dynamic> _$$SearchStateImplToJson(_$SearchStateImpl instance) =>
    <String, dynamic>{
      'query': instance.query,
      'history': instance.history,
      'isLoading': instance.isLoading,
      'hasError': instance.hasError,
    };
