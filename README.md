# Echo

Echo is an Arc Testnet checkout where the merchant web app and buyer iPhone app can both be offline during the QR handoff. The merchant signs an invoice QR; the buyer checks it, signs the same terms, and returns one QR containing both signatures. Each device then has the complete payment package. Whichever reconnects first uploads it to the always-on matcher, which settles prepaid native test USDC from the buyer's Arc escrow to the merchant on chain.

**A signed QR is pending, not paid.** After settlement, the online device displays an animated proof QR. The offline device reconstructs the proof and checks Arc validator precommits, receipt inclusion, and the exact `OrderPaid` event before showing Completed. A transaction hash alone is never treated as offline proof. If the buyer's escrow is too low when settlement runs, the order stays pending. The [queued payment option](OFFLINE_PAYMENT_PLAN.md) without escrow is a future plan.

## Run locally

Use Node 22 or newer. Run `npm ci`, `npm run compile`, and `npm run build`. Set `CHECKOUT_ADDRESS` to the deployed checkout contract and `MATCHER_PRIVATE_KEY` to a funded Arc Testnet wallet, then run `npm start`. The matcher listens on port 4173 by default and stores its queue in ignored `runtime/matches.json`. Keep the matcher key in an ignored file or secret manager.

Open **http://localhost:4173** on the merchant Mac for local development, or use the [one-device demo](https://blackout-next.64-177-121-208.sslip.io/). That hosted merchant page still shows the earlier Blackout branding; the Echo web styling in this branch has not been deployed there yet. The web app creates invoices, scans the buyer's return QR with the Mac camera or a QR image, and shows Sales, wallet balance, and receipts. Open it online once so its offline assets and validator checkpoint are cached. Back up the merchant testnet recovery key in Settings before clearing browser storage. An unscanned invoice can be cancelled while online; cancellation is recorded on the contract, so direct settlement cannot bypass it.

Open [the iPhone project](ios/BlackoutBuyer.xcodeproj) in Xcode, select your phone and signing team, and Run. The buyer app defaults to the hosted matcher and asks for confirmation after scanning an invoice. The iOS app stores its wallet in Keychain. Get Arc Testnet USDC from Circle's faucet for that wallet, then use **Add → Deposit to Arc escrow** while online. Keep a little in the wallet for Arc network fees. See [iOS setup](ios/README.md) for details.

## Demo

1. Prepare the buyer's Arc escrow and open both apps online once.
2. Take both devices offline. Create an invoice on the merchant web app and scan its QR with the buyer iPhone.
3. Confirm the signed terms on iPhone. Show the buyer's return QR to the merchant camera. Both devices show a pending state.
4. Reconnect either device. It uploads both signatures and the matcher submits the payment. The connected device displays animated Arc proof QR frames. The offline device scans them and verifies the proof before showing Completed.

The one-device demo uses the new cancellation-safe contract [`0xd132eA8D7cADD65B92be0B616Ae65Bbf6F0Af037`](https://explorer.testnet.arc.io/address/0xd132eA8D7cADD65B92be0B616Ae65Bbf6F0Af037). The [earlier demo](https://blackout.64-177-121-208.sslip.io/) still uses escrow contract [`0x38929cCE8c5914755587d41Bf78B9ccC401AAc4d`](https://explorer.testnet.arc.io/address/0x38929cCE8c5914755587d41Bf78B9ccC401AAc4d). Funds in it do not move to the new contract automatically. The iPhone home screen shows the previous escrow separately and offers **Move**, which withdraws and redeposits after Arc confirms. If redeposit fails, the funds remain in the buyer wallet and can be deposited from Settings.

Offline proof verification requires a validator checkpoint cached before disconnecting. Both clients compare the matcher's checkpoint with Arc's public RPC over HTTPS before caching it. The checkpoint covers only the next 1,800 blocks. **This testnet demo assumes the validator set stays unchanged during that window.** It does not yet prove validator-set transitions; production use needs a chain of authenticated transitions or another trusted checkpoint authority. Outside the cached window, verification fails closed.

The one-package settlement, on-chain cancellation, and exact payment proof passed live Arc Testnet checks. The full iPhone-to-Mac QR exchange, including the animated proof scan, still needs a physical test.

Run `npm test` and `forge test` for the intent matcher and escrow contract checks.
