/// Pengaturan blockchain publik tempat hash rantai dijangkarkan.
/// Tidak ada rahasia di sini; private key wallet hanya ada di Secrets Supabase.
abstract class ChainConfig {
  static const name = 'Ethereum Sepolia (testnet)';
  static const chainId = 11155111;

  /// Node RPC publik (hanya dipakai membaca transaksi untuk verifikasi).
  static const rpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com';

  static const explorerTxBase = 'https://sepolia.etherscan.io/tx/';

  /// Awalan data transaksi: "TPLT" dalam hex, diikuti 32 byte hash blok.
  static const dataMagic = '54504c54';

  /// Nama Edge Function di Supabase.
  static const functionName = 'anchor-chain';
}