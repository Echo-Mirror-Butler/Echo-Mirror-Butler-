const STELLAR_NETWORK = (import.meta.env.VITE_STELLAR_NETWORK ?? 'testnet') as 'testnet' | 'mainnet'

const CONFIGS = {
  testnet: {
    horizonUrl: import.meta.env.VITE_STELLAR_HORIZON_URL ?? 'https://horizon-testnet.stellar.org',
    explorerBaseUrl: import.meta.env.VITE_STELLAR_EXPLORER_BASE_URL ?? 'https://stellar.expert/explorer/testnet/tx/',
    networkPassphrase: 'Test SDF Network ; September 2015',
    isTestnet: true,
  },
  mainnet: {
    horizonUrl: import.meta.env.VITE_STELLAR_HORIZON_URL ?? 'https://horizon.stellar.org',
    explorerBaseUrl: import.meta.env.VITE_STELLAR_EXPLORER_BASE_URL ?? 'https://stellar.expert/explorer/public/tx/',
    networkPassphrase: 'Public Global Stellar Network ; September 2015',
    isTestnet: false,
  },
} as const

const resolvedConfig = CONFIGS[STELLAR_NETWORK] ?? CONFIGS.testnet

export const stellarConfig = {
  network: STELLAR_NETWORK,
  ...resolvedConfig,
}

export function txExplorerUrl(txHash: string): string {
  return `${stellarConfig.explorerBaseUrl}${txHash}`
}

export const isTestnet = stellarConfig.isTestnet
