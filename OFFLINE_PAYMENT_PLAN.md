# Queued payment option (planned)

The current app uses prepaid Arc escrow. A simpler future flow would remove that prepayment step:

1. While both phones are offline, the merchant and buyer exchange signed receive and send messages with the same order ID, merchant, and amount. Each phone saves its message locally.
2. When the buyer reconnects, the app submits the actual payment to Arc. The backend matches its transaction to the merchant's receive message whenever the merchant uploads it; either side can arrive first.
3. The merchant sees **pending** until Arc confirms the payment. If the buyer never reconnects or has insufficient funds, the sale remains unpaid.

This option is a plan, not implemented in the current escrow checkout.
