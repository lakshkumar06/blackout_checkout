# Blackout buyer for iPhone

Open `BlackoutBuyer.xcodeproj` in Xcode, choose your iPhone and personal signing team, then Run. The app defaults to `https://blackout.64-177-121-208.sslip.io`. Open it online once to cache the contract configuration. The matcher runs on a separate Vultr server, so the Mac can go offline during the demo.

The wallet key lives in iOS Keychain; Settings can show or import the recovery key. Use Circle's Arc Testnet faucet to fund this wallet, then use **Add → Deposit to Arc escrow**. Keep a little test USDC in the wallet for gas. The home Balance is prepaid escrow, not the wallet's uncommitted on-chain balance.

Scan a merchant invoice QR while offline, check the signed merchant address and amount, then confirm. The app stores the signed send intent and displays its QR for the merchant to scan. It uploads to the matcher automatically when reachable and checks status every 15 seconds. Payment remains pending until both signed intents match and Arc settles. The simulator cannot use a physical camera; the scanner includes a paste-JSON option for development.

`bridge.mjs` is bundled into `BlackoutBuyer/Resources/bridge.js` with the repository's `esbuild`. The bundled ethers bridge verifies the merchant's EIP-712 signature, signs buyer intents, and signs escrow deposits locally. Rebuild with `npm ci && ./node_modules/.bin/esbuild ios/bridge.mjs --bundle --platform=browser --target=safari17 --format=iife --minify --outfile=ios/BlackoutBuyer/Resources/bridge.js` after changing it.
