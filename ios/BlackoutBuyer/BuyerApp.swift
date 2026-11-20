import SwiftUI

@main struct BuyerApp: App {
  @StateObject private var model = CheckoutModel()
  var body: some Scene { WindowGroup { BuyerView().environmentObject(model).preferredColorScheme(.dark) } }
}
