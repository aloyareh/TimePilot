import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/blockchain/anchor_service.dart';
import 'package:time_pilot/features/blockchain/chain.dart';


List<Block> _blocks(int n) {
  final out = <Block>[];
  for (var i = 0; i < n; i++) {
    out.add(
      Block.create(
        prev: out.isEmpty ? null : out.last,
        endedAtUtc: DateTime.utc(2026, 10, 1, i),
        sessionId: 's$i',
        taskId: 't$i',
        clientId: 'c',
        durationSeconds: 3600,
        lateMinutes: 0,
        currency: 'IDR',
        netMinor: 100000 + i,
      ),
    );
  }
  return out;
}

Anchor _anchorFor(Block b) => Anchor(
  uptoIdx: b.index,
  blockHash: b.hash,
  txHash: '0x${'1' * 64}',
  chainId: 11155111,
  createdAt: DateTime.utc(2026, 10, 24),
);

Map<String, dynamic> _tx(Anchor a, {String? input, String? blockNumber = '0x10'}) => {
  'input': input ?? a.expectedInput,
  'from': '0xAbC0000000000000000000000000000000000001',
  'to': '0xabc0000000000000000000000000000000000001',
  'blockNumber': blockNumber,
};

void main() {
  group('interpretAnchorTx', () {
    final blocks = _blocks(3);
    final anchor = _anchorFor(blocks.last);

    test('transaksi cocok dan sudah masuk blok -> confirmed', () {
      final r = interpretAnchorTx(_tx(anchor), anchor);
      expect(r.status, AnchorStatus.confirmed);
      expect(r.blockNumber, 16);
    });

    test('belum masuk blok -> pending', () {
      expect(
        interpretAnchorTx(_tx(anchor, blockNumber: null), anchor).status,
        AnchorStatus.pending,
      );
    });

    test('tidak ada transaksi -> notFound', () {
      expect(interpretAnchorTx(null, anchor).status, AnchorStatus.notFound);
    });

    test('data transaksi berbeda -> mismatch', () {
      final other = '0x54504c54${'f' * 64}';
      expect(
        interpretAnchorTx(_tx(anchor, input: other), anchor).status,
        AnchorStatus.mismatch,
      );
    });

    test('transaksi bukan ke diri sendiri -> mismatch', () {
      final tx = _tx(anchor)..['to'] = '0xdead';
      expect(interpretAnchorTx(tx, anchor).status, AnchorStatus.mismatch);
    });
  });

  group('localChainMatchesAnchor', () {
    test('rantai utuh dan hash sama -> true', () {
      final blocks = _blocks(4);
      expect(localChainMatchesAnchor(_anchorFor(blocks[2]), blocks), isTrue);
      expect(localChainMatchesAnchor(_anchorFor(blocks[3]), blocks), isTrue);
    });

    test('data blok lama diubah -> false', () {
      final blocks = _blocks(4);
      final anchor = _anchorFor(blocks[3]);
      blocks[1] = blocks[1].tampered(netMinor: 999999999);
      expect(localChainMatchesAnchor(anchor, blocks), isFalse);
    });

    test('blok hilang di HP -> false', () {
      final blocks = _blocks(4);
      final anchor = _anchorFor(blocks[3]);
      expect(localChainMatchesAnchor(anchor, blocks.sublist(0, 3)), isFalse);
    });

    test('hash yang dijangkarkan beda dari lokal -> false', () {
      final blocks = _blocks(3);
      final a = Anchor(
        uptoIdx: 2,
        blockHash: 'e' * 64,
        txHash: '0x${'1' * 64}',
        chainId: 1,
        createdAt: DateTime.utc(2026),
      );
      expect(localChainMatchesAnchor(a, blocks), isFalse);
    });
  });
}