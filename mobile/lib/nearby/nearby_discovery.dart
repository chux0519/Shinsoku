import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import 'nearby_models.dart';

const nearbyBonjourService = '_shinsoku-mic._tcp.local';

class NearbyDiscoveryService {
  Future<List<NearbyDesktop>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = MDnsClient();
    try {
      await client.start();
      final pointers = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(nearbyBonjourService),
            timeout: timeout,
          )
          .toList();
      final resolved = await Future.wait(
        pointers.map((pointer) => _resolve(client, pointer, timeout)),
      );
      final unique = <String, NearbyDesktop>{};
      for (final desktop in resolved.whereType<NearbyDesktop>()) {
        unique[desktop.instanceId] = desktop;
      }
      final desktops = unique.values.toList()
        ..sort((left, right) => left.serviceName.compareTo(right.serviceName));
      return desktops;
    } finally {
      client.stop();
    }
  }

  Future<NearbyDesktop?> _resolve(
    MDnsClient client,
    PtrResourceRecord pointer,
    Duration timeout,
  ) async {
    final results = await Future.wait([
      client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(pointer.domainName),
            timeout: timeout,
          )
          .toList(),
      client
          .lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(pointer.domainName),
            timeout: timeout,
          )
          .toList(),
    ]);
    final services = results[0].whereType<SrvResourceRecord>().toList();
    final textRecords = results[1].whereType<TxtResourceRecord>().toList();
    if (services.isEmpty || textRecords.isEmpty) {
      return null;
    }

    final fields = <String, String>{};
    for (final line in textRecords.first.text.split('\n')) {
      final separator = line.indexOf('=');
      if (separator > 0) {
        fields[line.substring(0, separator)] = line.substring(separator + 1);
      }
    }
    final fingerprint = normalizeCertificateFingerprint(fields['fp'] ?? '');
    final instance = (fields['instance'] ?? '').toLowerCase();
    if (fields['v'] != '1' ||
        fields['transport'] != 'wss' ||
        !isCertificateFingerprint(fingerprint) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(instance)) {
      return null;
    }

    final service = services.first;
    final suffix = '.$nearbyBonjourService';
    final serviceName = pointer.domainName.endsWith(suffix)
        ? pointer.domainName.substring(
            0,
            pointer.domainName.length - suffix.length,
          )
        : pointer.domainName;
    return NearbyDesktop(
      serviceName: serviceName,
      host: service.target.endsWith('.')
          ? service.target.substring(0, service.target.length - 1)
          : service.target,
      port: service.port,
      certificateSha256: fingerprint,
      instanceId: instance,
    );
  }
}
