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
| Node | Execution | Version Target | Consensus | Version Target | Checkpoint URL |
| --- | --- | --- | --- | --- | --- |
| node001 | [[TODO]] | [[TODO]] | [[TODO]] | [[TODO]] | [[TODO]] |
| node002 | [[TODO]] | [[TODO]] | [[TODO]] | [[TODO]] | [[TODO]] |

- Fallback EC/CC Endpoints: [[TODO]]

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
- MEV-Boost Relay Profiles: [[TODO]]

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
- Wallet Init (node001): [[TODO date / tx hash]]
- Set Withdrawal Address: [[TODO]]
- Initialize Fee Distributor: [[TODO]]
- Join Smoothing Pool: [[TODO]]
- MEV-Boost Verification Snapshot: [[TODO]]

## Validator & Minipool Targets
- Initial LEB8 Count: [[TODO]]
- Planned Scale-Up: [[TODO]]
- Beaconcha.in Watchlist IDs: [[TODO]]

## Monitoring & Alerts
- Grafana URL: [[TODO]]
- Alert Destinations: [[TODO]]
- Key Dashboard IDs: [[TODO]]

## Change Log
| Date | Change | Notes |
| --- | --- | --- |
| [[TODO]] | Created document | Derived from mainnet-migration-plan.md |

