# Mainnet Reference

## Tangem Wallet Inventory
- Card Set Distribution: [Card Grey - Primary, Card Red - Safe, Card Yellow - Travel]
- Primary Ethereum Address (EIP-55): [0x803b07DE402Ad93BB4315C0B4D38195e56bf8E7d]
- Verification Notes: [[TODO]]
- Backup Notes: [[TODO]]

## Rocket Pool Node Wallets
| Node | Wallet Address | Creation Date | Storage Notes |
| --- | --- | --- | --- |
| node001 | `0x0A77C4B4EE9Ab193514b9d8bEe25d7eF09f4917F` | 2026-01-15 | LUKS USB `/mnt/validator_keys/data` |
| node002 | (standby - no wallet) | — | Will initialize on failover only |

- Mnemonic Storage Location: [[TODO]]
- Password File Strategy: [[TODO]]

## Withdrawal / Fee Distributor Settings
- Primary Withdrawal Address: `0x803b07DE402Ad93BB4315C0B4D38195e56bf8E7d` (confirmed 2026-01-15)
- Fee Distributor Address: `0x5d5BD99F6A078E796a95e0266b6333cbb3bC67C0`
- RPL Withdrawal Address: (not set - defaults to primary)
- Transaction References: [[TODO]]

## Execution & Consensus Clients
| Node | Execution | Version | Consensus | Version | Checkpoint URL |
| --- | --- | --- | --- | --- | --- |
| node001 | Reth | v1.9.2 | Lighthouse | v8.0.1 | `https://beaconstate.ethstaker.cc` |
| node002 | Nethermind | 1.35.8 | Lighthouse | v8.0.1 | `https://beaconstate.ethstaker.cc` |

- Fallback EC/CC Endpoints:
  - node001 fallback → node002: `http://192.168.60.102:8545` (EC), `http://192.168.60.102:5052` (CC)
  - node002 fallback → node001: `http://192.168.60.101:8545` (EC), `http://192.168.60.101:5052` (CC)

## Storage & Encryption
- LUKS Device UUID: [[TODO]]
- Mount Point: `/mnt/validator_keys`
- Symlink Check Result: [[TODO]]
- Keyfile Path: `/root/luks-keyfile`
- Systemd Units: `validator-keys-unlock.service`, `mnt-validator_keys.mount`
- Backup Media Locations: [[TODO]]

## Network & RPC References
- Public IP (shared): `158.140.242.211`
- LAN IP (node001): `192.168.60.101`
- LAN IP (node002): `192.168.60.102`
- LAN Subnet: `192.168.60.0/24`
- MEV-Boost Relay Profiles:
  - Ultrasound.money (0xa1559ace...)
  - Aestus.live (0xa15b5257...)
  - Titan Relay (0x8c4ed5e2...)

### Firewall / NAT Port Forwarding Rules
**External IP:** `158.140.242.211`

**Node001 (192.168.60.101)** - Reth + Lighthouse:
- `TCP 9001` → `192.168.60.101:9001` (Execution client P2P - Reth)
- `TCP/UDP 30303` → `192.168.60.101:30303` (Execution client P2P - standard Ethereum)
- `UDP 8001` → `192.168.60.101:8001` (Consensus client discovery - Lighthouse)

**Node002 (192.168.60.102)** - Nethermind + Lighthouse:
- `TCP 9002` → `192.168.60.102:9002` (Execution client P2P - Nethermind)
- `TCP/UDP 30304` → `192.168.60.102:30304` (Execution client P2P)
- `UDP 8002` → `192.168.60.102:8002` (Consensus client discovery - Lighthouse)

**Note:** These port mappings are **network-agnostic** (work for both Hoodi testnet and Ethereum mainnet). No changes required during migration - the P2P protocols use the same ports regardless of network.

## Migration Transaction Log
- Wallet Init (node001): 2026-01-15
- Node Registration: 2026-01-15 (timezone: Etc/UTC)
- Set Withdrawal Address: 2026-01-15 (confirmed via WalletConnect/Tangem)
- Initialize Fee Distributor: Auto-initialized during registration
- Join Smoothing Pool: 2026-01-15
- MEV-Boost Verification: 2026-01-15 (3 relays active)
- **Minipool Creation:** Pending Saturn 1 launch (~Feb 2026)

## Validator & Minipool Targets
- **Strategy:** Wait for Saturn 1 (LEB4 megapools) - see [saturn1-analysis.md](saturn1-analysis.md)
- Initial Deployment: 14× LEB4 validators (56 ETH bonded)
- Expected Launch: ~Feb 2026 (Saturn 1)
- Beaconcha.in Watchlist IDs: (pending validator creation)

## Monitoring & Alerts
- Grafana URL: [[TODO]]
- Alert Destinations: [[TODO]]
- Key Dashboard IDs: [[TODO]]

## Change Log
| Date | Change | Notes |
| --- | --- | --- |
| 2026-01-15 | Mainnet migration completed | Node registered, withdrawal address confirmed, smoothing pool joined |
| 2026-01-15 | Awaiting Saturn 1 | Deposits paused; will create 14× LEB4 megapool validators |
| 2026-01-10 | Created document | Derived from mainnet-migration-plan.md |

