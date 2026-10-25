import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../data/remote/session_storage.dart';
import 'chain.dart';
import 'chain_config.dart';

class AnchorException implements Exception {
  const AnchorException(this.code);
  final String code;

  String get message => switch (code) {
    'SESSION_INVALID' => 'Sesi berakhir. Masuk ulang untuk melanjutkan.',
    'NO_BLOCKS' => 'Belum ada blok yang tersinkron ke server.',
    'ALREADY_ANCHORED' => 'Blok terbaru sudah dijangkarkan.',
    'WALLET_EMPTY' =>
      'Saldo wallet jangkar habis. Isi ulang dari faucet Sepolia.',
    'WALLET_NOT_CONFIGURED' => 'Wallet jangkar belum diatur di server.',
    'CHAIN_ERROR' => 'Node blockchain tidak merespons. Coba lagi nanti.',
    'NETWORK' => 'Tidak ada koneksi internet.',
    _ => 'Gagal menjangkarkan ($code).',
  };

  @override
  String toString() => 'AnchorException($code)';
}

/// Satu jangkar: hash blok #[uptoIdx] tercatat di transaksi [txHash].
class Anchor {
  const Anchor({
    required this.uptoIdx,
    required this.blockHash,
    required this.txHash,
    required this.chainId,
    required this.createdAt,
  });

  final int uptoIdx;
  final String blockHash;
  final String txHash;
  final int chainId;
  final DateTime createdAt;

  /// Data transaksi yang seharusnya tercatat di blockchain.
  String get expectedInput => '0x${ChainConfig.dataMagic}$blockHash';

  String get explorerUrl => '${ChainConfig.explorerTxBase}$txHash';

  factory Anchor.fromJson(Map<String, dynamic> j) => Anchor(
    uptoIdx: (j['upto_idx'] as num).toInt(),
    blockHash: j['block_hash'] as String,
    txHash: j['tx_hash'] as String,
    chainId: (j['chain_id'] as num).toInt(),
    createdAt: j['created_at'] == null
        ? DateTime.now()
        : DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

enum AnchorStatus {
  /// Transaksi ada di blockchain dan isinya sama dengan hash yang dijangkarkan.
  confirmed,

  /// Transaksi ditemukan tapi belum masuk blok.
  pending,

  /// Transaksi tidak ditemukan node (belum menyebar, atau hash salah).
  notFound,

  /// Transaksi ada tetapi isinya berbeda dari yang seharusnya.
  mismatch,
}

class AnchorCheck {
  const AnchorCheck(this.status, {this.blockNumber});
  final AnchorStatus status;
  final int? blockNumber;
}

/// Menafsirkan hasil `eth_getTransactionByHash` terhadap [anchor]. Fungsi murni.
AnchorCheck interpretAnchorTx(Map<String, dynamic>? tx, Anchor anchor) {
  if (tx == null) return const AnchorCheck(AnchorStatus.notFound);
  final input = (tx['input'] as String? ?? '').toLowerCase();
  final from = (tx['from'] as String? ?? '').toLowerCase();
  final to = (tx['to'] as String? ?? '').toLowerCase();
  if (input != anchor.expectedInput.toLowerCase() || from.isEmpty || from != to) {
    return const AnchorCheck(AnchorStatus.mismatch);
  }
  final bn = tx['blockNumber'] as String?;
  if (bn == null) return const AnchorCheck(AnchorStatus.pending);
  return AnchorCheck(
    AnchorStatus.confirmed,
    blockNumber: int.tryParse(bn.replaceFirst('0x', ''), radix: 16),
  );
}

/// true bila rantai lokal sampai blok #uptoIdx masih utuh DAN hash blok itu
/// sama dengan yang dijangkarkan. Berubahnya data blok mana pun sebelumnya
/// ikut mengubah hash ini, jadi manipulasi riwayat terdeteksi.
bool localChainMatchesAnchor(Anchor anchor, List<Block> blocks) {
  if (anchor.uptoIdx >= blocks.length) return false;
  final upto = blocks.sublist(0, anchor.uptoIdx + 1);
  if (firstInvalidIndex(upto) != null) return false;
  return upto.last.hash == anchor.blockHash;
}

class AnchorService {
  AnchorService({
    SupabaseClient? client,
    SessionStorage? storage,
    http.Client? httpClient,
  }) : _client = client ?? Supabase.instance.client,
       _storage = storage ?? const SessionStorage(),
       _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final SessionStorage _storage;
  final http.Client _http;

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null) throw const AnchorException('SESSION_INVALID');
    return t;
  }

  /// Menjangkarkan blok terbaru yang sudah ada di server.
  Future<Anchor> anchorNow() async {
    final token = await _token();
    try {
      final res = await _client.functions.invoke(
        ChainConfig.functionName,
        body: {'token': token},
        headers: {'apikey': Env.supabasePublishableKey},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return Anchor(
        uptoIdx: (data['idx'] as num).toInt(),
        blockHash: data['hash'] as String,
        txHash: data['txHash'] as String,
        chainId: (data['chainId'] as num).toInt(),
        createdAt: DateTime.now(),
      );
    } on FunctionException catch (e) {
      final d = e.details;
      throw AnchorException(
        d is Map && d['error'] is String ? d['error'] as String : 'CHAIN_ERROR',
      );
    } catch (_) {
      throw const AnchorException('NETWORK');
    }
  }

  Future<List<Anchor>> list() async {
    final token = await _token();
    try {
      final res = await _client.rpc('app_anchor_list', params: {'p_token': token});
      return (res as List)
          .map((e) => Anchor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw AnchorException(e.message);
    } catch (_) {
      throw const AnchorException('NETWORK');
    }
  }

  /// Membaca transaksi langsung dari node blockchain (bukan dari server kita).
  Future<AnchorCheck> verifyOnChain(Anchor anchor) async {
    try {
      final res = await _http
          .post(
            Uri.parse(ChainConfig.rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'eth_getTransactionByHash',
              'params': [anchor.txHash],
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw const AnchorException('CHAIN_ERROR');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (body['error'] != null) throw const AnchorException('CHAIN_ERROR');
      final tx = body['result'];
      return interpretAnchorTx(
        tx == null ? null : Map<String, dynamic>.from(tx as Map),
        anchor,
      );
    } on AnchorException {
      rethrow;
    } catch (_) {
      throw const AnchorException('CHAIN_ERROR');
    }
  }
}