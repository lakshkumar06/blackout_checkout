# Blackout Checkout

Blackout Checkout is an Arc Testnet checkout where the merchant web app and buyer iPhone app can both be offline during the QR handoff. The merchant signs an invoice QR; the buyer scans it, checks the amount and merchant address, signs a matching payment, and shows a return QR. Each device keeps its own intent locally and uploads it when it reconnects. The matcher waits for both signatures, then settles prepaid native test USDC from the buyer's Arc escrow to the merchant on chain.

**A signed QR is pending, not paid.** The merchant shows a verified receipt only after the Arc transaction succeeds. If the buyer's escrow is too low when settlement runs, the order stays pending. The [queued payment option](OFFLINE_PAYMENT_PLAN.md) without escrow is a future plan.

## Run locally

Use Node 22 or newer. Run `npm ci`, `npm run compile`, and `npm run build`. Set `CHECKOUT_ADDRESS` to the deployed checkout contract and `MATCHER_PRIVATE_KEY` to a funded Arc Testnet wallet, then run `npm start`. The matcher listens on port 4173 by default and stores its queue in ignored `runtime/matches.json`. Keep the matcher key in an ignored file or secret manager.

Open **http://localhost:4173** on the merchant Mac for local development, or use the [hosted demo](https://blackout.64-177-121-208.sslip.io/). The web app creates invoices, scans the buyer's return QR with the Mac camera or a QR image, and shows Sales, wallet balance, and receipts. Open it online once so its offline assets are cached. Back up the merchant testnet recovery key in Settings before clearing browser storage. An unscanned invoice can be cancelled while online; the matcher keeps a cancellation record so later uploads cannot pay it.

Open [the iPhone project](ios/BlackoutBuyer.xcodeproj) in Xcode, select your phone and signing team, and Run. The buyer app defaults to the hosted matcher and asks for confirmation after scanning an invoice. The iOS app stores its wallet in Keychain. Get Arc Testnet USDC from Circle's faucet for that wallet, then use **Add → Deposit to Arc escrow** while online. Keep a little in the wallet for Arc network fees. See [iOS setup](ios/README.md) for details.

## Demo

1. Prepare the buyer's Arc escrow and open both apps online once.
2. Take both devices offline. Create an invoice on the merchant web app and scan its QR with the buyer iPhone.
3. Confirm the signed terms on iPhone. Show the buyer's return QR to the merchant camera. Both devices show a pending state.
4. Reconnect either device first; its intent waits in the matcher. Reconnect the other; the matcher submits the matched order to Arc. Both sides show verified only after settlement.

The deployed contract is [`0x38929cCE8c5914755587d41Bf78B9ccC401AAc4d`](https://explorer.testnet.arc.io/address/0x38929cCE8c5914755587d41Bf78B9ccC401AAc4d). The matcher runs on a separate Vultr server, so it remains online while both demo devices are offline.

Run `npm test` and `forge test` for the intent matcher and escrow contract checks.
