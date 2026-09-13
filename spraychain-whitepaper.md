# SprayChain — Decentralized Money Spraying Protocol
### Whitepaper v1.0 | September 2026

---

## Abstract

SprayChain is a Web3 celebration protocol that brings the beloved Nigerian and African party tradition of "money spraying" onto the blockchain. Guests at events, fans of artists, or anyone celebrating a person can connect their wallet and spray crypto tokens at an honoree in real time — with a cinematic spray animation, configurable drip rate, and on-chain settlement. SprayChain turns a cultural ritual into a transparent, peer-to-peer gifting primitive.

---

## 1. Background & Motivation

Money spraying is a celebratory tradition common at Nigerian parties, weddings, and festivals. Well-wishers physically rain banknotes on a celebrant as a gesture of honor and abundance. The practice is emotionally resonant and communally visible — everyone sees who is celebrated and how generously.

Web3 gifts today are cold: a wallet-to-wallet transfer, a block explorer hash. SprayChain restores the spectacle. A sprayer selects the rate (0.10 USDC/tick, 0.50 USDC/tick, 1 USDC/tick), presses the Spray button, and digital dollars fly outward on screen while an on-chain contract accumulates the total. When the spray session ends, the contract transfers the full amount to the honoree with a human-readable notification attached: *"You received $12.50 from Akin — Happy Birthday Queen 🎉"*

---

## 2. System Architecture

```
Sprayer Browser
    │
    ├─ Next.js / HTML Frontend
    │       ├─ Wallet connect (wagmi / MetaMask)
    │       ├─ Party form (name, address, rate)
    │       ├─ Spray canvas (animated dollar shower)
    │       └─ Session summary + receipt
    │
    ▼
SprayMachine.sol  (EVM — Celo Mainnet / Botchain)
    │
    ├─ receiveSpray(honoreeAddr, honoreeTag)  payable
    │       ├─ Accumulates CELO/token from msg.value
    │       ├─ Emits SprayTick event per tick
    │       └─ Calls internal _settle() on close
    │
    ├─ closeSpray(sessionId)
    │       ├─ Transfers cumulative amount to honoree
    │       └─ Emits SprayClosed(sessionId, from, to, amount, tag)
    │
    └─ getSession(sessionId) → view
```

---

## 3. Smart Contract Specification

### 3.1 SprayMachine.sol

| Function | Visibility | Description |
|---|---|---|
| `openSpray(address honoree, string tag)` | `external payable` | Opens a new spray session, deposits initial amount, emits `SprayOpened` |
| `addSpray(bytes32 sessionId)` | `external payable` | Adds to an active session (each UI tick calls this) |
| `closeSpray(bytes32 sessionId)` | `external` | Caller (sprayer) closes session; contract pushes full balance to honoree |
| `getSession(bytes32 sessionId)` | `external view` | Returns session metadata: sprayer, honoree, tag, total, status |

### 3.2 Events

```solidity
event SprayOpened(bytes32 indexed sessionId, address indexed sprayer, address indexed honoree, string tag);
event SprayTick(bytes32 indexed sessionId, uint256 amount, uint256 cumulative);
event SprayClosed(bytes32 indexed sessionId, address sprayer, address honoree, uint256 total, string tag);
```

### 3.3 Security Properties

- **Non-custodial**: Contract never holds funds across blocks beyond the active session. `closeSpray` performs an immediate push transfer.
- **Session ownership**: Only the original sprayer may call `closeSpray` on their session.
- **Reentrancy guard**: All state mutations happen before external calls (`checks-effects-interactions`).
- **No admin keys**: No owner or pauser — the contract is immutable after deployment.

---

## 4. Token Support

SprayChain v1 launches on **Celo Mainnet** using **native CELO** as the spray token (low gas, mobile-first chain). A v1.1 upgrade will add `cUSD` (Celo Dollar stablecoin) and `USDC` via ERC-20 approve/transferFrom, making spray amounts denominated in real dollars — natural for the gifting use case.

On **Botchain** (chain ID 677) the native gas token is used directly, following the same model.

---

## 5. Rate Ticks — UX to Contract Mapping

The spray rate chosen in the UI maps to smart contract calls:

| Rate Setting | Contract behaviour |
|---|---|
| 0.10 USD/tick | `addSpray()` called every 500ms with 0.10 USD equivalent in CELO |
| 0.50 USD/tick | `addSpray()` called every 500ms with 0.50 USD equivalent |
| 1.00 USD/tick | `addSpray()` called every 500ms with 1.00 USD equivalent |
| Custom | User types any positive value; UI converts to wei before call |

Gas batching: the frontend batches up to 10 ticks per transaction to keep gas overhead manageable. Visual tick rate remains smooth — UI animates at full speed while contract calls are batched.

---

## 6. Notification Layer

On `SprayClosed` event emission, an off-chain indexer (The Graph subgraph or a lightweight FastAPI webhook listener) catches the event and:

1. Resolves the honoree address to any registered display name (optional ENS / Celo Name Service).
2. Pushes a notification payload via WebSocket to any open browser session watching that address.
3. Logs the spray receipt in a Supabase table for history queries.

Notification format: `"🎉 {sprayer_tag} sprayed ${total} on {honoree_name}!"`

---

## 7. Fee Model

SprayChain v1 charges **zero protocol fees**. 100% of sprayed value reaches the honoree. This is intentional — the product goal is adoption and cultural resonance, not extraction. Future versions may introduce an optional 0.5% tip to a community treasury, governed by SPRAY token holders.

---

## 8. Privacy

- All spray transactions are on-chain and publicly visible.
- The honoree tag (name typed by sprayer) is stored as calldata — visible on-chain.
- No off-chain KYC or identity verification is required.
- SprayChain is non-custodial; Anthropic / FaucetDrops never holds user funds.

---

## 9. Roadmap

| Phase | Milestone |
|---|---|
| v1.0 | Native CELO spray on Celo Mainnet + Botchain; HTML frontend; SprayMachine.sol |
| v1.1 | cUSD / USDC ERC-20 spray; mobile-optimised PWA |
| v1.2 | Party rooms — shared URL where multiple guests spray the same honoree simultaneously; live leaderboard |
| v2.0 | SPRAY governance token; community treasury; cross-chain bridges (Base, Arbitrum) |
| v2.1 | NFT spray receipts — each spray session mints a commemorative NFT sent to honoree |

---

## 10. Conclusion

SprayChain is the first on-chain implementation of money spraying — a tradition that has connected communities, honored individuals, and expressed joy across Africa and the diaspora for generations. By encoding that ritual into a smart contract and giving it a cinematic frontend, SprayChain makes Web3 feel human, festive, and culturally rooted.

*Build on SprayChain. Spray with pride.*

---

*© 2026 FaucetDrops / SprayChain. All rights reserved.*
