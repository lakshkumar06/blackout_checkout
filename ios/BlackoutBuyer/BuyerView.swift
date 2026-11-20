import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

private enum C {
  static let bg=Color(red:11/255,green:11/255,blue:12/255)
  static let fg=Color(red:250/255,green:250/255,blue:250/255)
  static let muted=Color(red:139/255,green:139/255,blue:147/255)
  static let border=Color(red:35/255,green:35/255,blue:39/255)
  static let surface=Color(red:22/255,green:22/255,blue:24/255)
  static let green=Color(red:74/255,green:222/255,blue:128/255)
}
private struct CircleIcon: View {
  let symbol:String
  var size:CGFloat=52
  var body:some View { Image(systemName:symbol).font(.custom("Inter",size:22).weight(.regular)).frame(width:size,height:size).background(C.surface,in:Circle()).overlay(Circle().stroke(C.border)) }
}
private struct Avatar: View {
  let text:String
  var size:CGFloat=40
  var body:some View { Text(text).font(.custom("Inter",size:size/3).weight(.semibold)).foregroundStyle(Color(red:201/255,green:201/255,blue:207/255)).frame(width:size,height:size).background(Color(red:26/255,green:26/255,blue:30/255),in:Circle()).overlay(Circle().stroke(C.border)) }
}
struct BuyerView: View {
  @EnvironmentObject private var m:CheckoutModel
  @State private var imported=""
  @State private var depositAmount=""
  @State private var showAmounts=false
  var body:some View {
    ZStack {
      C.bg.ignoresSafeArea()
      Group { switch m.screen {
      case .home: home
      case .confirm: confirm
      case .proof: proof
      case .activity: activity
      } }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    .foregroundStyle(C.fg)
    .fontDesign(.default)
    .alert("Checkout",isPresented:Binding(get:{m.message != nil},set:{ if !$0 {m.message=nil} })) { Button("OK",role:.cancel){m.message=nil} } message:{Text(m.message ?? "")}
    .sheet(isPresented:$m.showingScanner) { ScannerSheet { code in Task { await m.scan(code) } } }
    .sheet(isPresented:$m.showingSettings) { settings }
    .sheet(isPresented:$m.showingImport) { importSheet }
  }
  private var home:some View {
    VStack(alignment:.leading,spacing:0) {
      HStack(spacing:10) {
        Avatar(text:"AC",size:36)
        VStack(alignment:.leading,spacing:2) { Text("Good evening").font(.custom("Inter",size:12)).foregroundStyle(C.muted);Text("Ava Chen").font(.custom("Inter",size:15).weight(.semibold)) }
        Spacer()
        Button { m.showingSettings=true } label:{Image(systemName:"gearshape").font(.custom("Inter",size:19)).frame(width:40,height:40).overlay(Circle().stroke(C.border))}
      }.padding(.top,8)
      Text("Available to pay").font(.custom("Inter",size:13).weight(.medium)).foregroundStyle(C.muted).padding(.top,32)
      HStack(alignment:.firstTextBaseline,spacing:10) {
        Text(CheckoutModel.money(m.balance))
          .font(.custom("Inter",size:60).weight(.semibold)).tracking(-2.7).minimumScaleFactor(0.5).lineLimit(1)
          .foregroundStyle(C.fg)
        Text("USDC").font(.custom("Inter",size:15).weight(.medium)).foregroundStyle(C.muted)
      }.padding(.top,8)
      HStack(spacing:8) {
        action("Pay","viewfinder") { m.showingScanner=true }
        action("Add","plus") { m.showingSettings=true }
        action("Send","arrow.up.right") { m.showingScanner=true }
        action("Receipts","receipt") { m.screen = .activity }
      }.padding(.top,28)
      HStack {Text("Recent").font(.custom("Inter",size:16).weight(.semibold));Spacer();Button {showAmounts.toggle()} label:{Image(systemName:showAmounts ? "eye.slash" : "eye").font(.custom("Inter",size:16))}.accessibilityLabel(showAmounts ? "Hide transaction amounts" : "Show transaction amounts").foregroundStyle(C.muted);Button("See all") { m.screen = .activity }.font(.custom("Inter",size:14)).foregroundStyle(C.muted).padding(.leading,12) }.padding(.top,32)
      if m.orders.isEmpty { Text("No payments yet").foregroundStyle(C.muted).font(.custom("Inter",size:14)).padding(.top,24) }
      else { ForEach(m.orders.prefix(3)) { order in Button {m.screen = .activity} label:{ orderRow(order) }.buttonStyle(.plain) } }
      Spacer(minLength:0)
    }
    .padding(.horizontal,24)
    .safeAreaInset(edge:.bottom,spacing:0) { bottomBar }
    .task { await m.refreshBalance() }
  }
  private func action(_ title:String,_ symbol:String,_ perform:@escaping()->Void)->some View {
    Button(action:perform) { VStack(spacing:8) {CircleIcon(symbol:symbol);Text(title).font(.custom("Inter",size:13).weight(.medium))}.frame(maxWidth:.infinity) }.buttonStyle(.plain)
  }
  private var bottomBar:some View {
    HStack(alignment:.center) {
      Button {m.screen = .home} label:{VStack(spacing:4){Image(systemName:"house").font(.custom("Inter",size:23));Text("Home").font(.custom("Inter",size:11))}.frame(width:64)}
      Spacer()
      Button {m.showingScanner=true} label:{Image(systemName:"viewfinder").font(.custom("Inter",size:26)).foregroundStyle(C.bg).frame(width:56,height:56).background(C.fg,in:Circle())}.accessibilityLabel("Scan to pay")
      Spacer()
      Button {m.screen = .activity} label:{VStack(spacing:4){Image(systemName:"waveform.path.ecg").font(.custom("Inter",size:23));Text("Activity").font(.custom("Inter",size:11))}.frame(width:64).foregroundStyle(m.screen == .activity ? C.fg : C.muted)}
    }
    .padding(.horizontal,28)
    .frame(height:74)
    .background(C.bg)
    .overlay(alignment:.top){C.border.frame(height:1)}
  }
  private func orderRow(_ order:Order)->some View {
    HStack(spacing:14) {Avatar(text:"GC");VStack(alignment:.leading,spacing:2){Text(short(order.send.vendor)).font(.custom("Inter",size:15).weight(.medium));Text(order.created,style:.date).font(.custom("Inter",size:13)).foregroundStyle(C.muted)};Spacer();VStack(alignment:.trailing,spacing:2){Text(showAmounts ? "−"+CheckoutModel.money(order.send.amount) : "−****").font(.custom("Inter",size:15).weight(.medium));Text(order.status == "settled" ? "Verified" : "Pending").font(.custom("Inter",size:12)).foregroundStyle(C.muted)}}.padding(.vertical,14)
  }
  private var confirm:some View {
    VStack(spacing:0) {
      HStack {Button {m.screen = .home} label:{Image(systemName:"xmark").font(.custom("Inter",size:18)).frame(width:40,height:40).overlay(Circle().stroke(C.border))};Spacer();Text("Review payment").font(.custom("Inter",size:16).weight(.semibold));Spacer();Color.clear.frame(width:40,height:40)}
      VStack(spacing:0) {Avatar(text:"GC",size:64);Text(m.pendingReceive?.merchantName ?? "Merchant").font(.custom("Inter",size:17).weight(.semibold)).padding(.top,14);Text(short(m.pendingReceive?.vendor ?? "")).font(.custom("Inter",size:13)).foregroundStyle(C.muted).padding(.top,2)
        Text(CheckoutModel.money(m.pendingReceive?.amount ?? "0")).font(.custom("Inter",size:72).weight(.semibold)).tracking(-3.2).padding(.top,24)
        Text("USDC").font(.custom("Inter",size:14)).foregroundStyle(C.muted).padding(.top,0)
      }.frame(maxWidth:.infinity).padding(.top,36)
      VStack(spacing:0) {detail("Pay from","Escrow · \(CheckoutModel.money(m.balance))");detail("Network","Arc Testnet");detail("Invoice",short(m.pendingReceive?.id ?? ""))}.padding(.horizontal,18).background(Color(red:17/255,green:17/255,blue:19/255),in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(C.border)).padding(.top,32)
      Spacer()
      Button {Task {await m.authorize()}} label:{HStack(spacing:8){Image(systemName:"checkmark.shield");Text(m.busy ? "Signing…" : "Confirm payment")}.frame(maxWidth:.infinity).frame(height:54).background(C.fg,in:RoundedRectangle(cornerRadius:16)).foregroundStyle(C.bg).font(.custom("Inter",size:16).weight(.semibold))}.disabled(m.busy)
      Text("Scanning only reads the invoice. Confirm to sign; funds move after both sides reconnect.").font(.custom("Inter",size:13)).foregroundStyle(C.muted).multilineTextAlignment(.center).padding(.top,12)
    }.padding(.horizontal,24).padding(.top,8).padding(.bottom,24)
  }
  private func detail(_ left:String,_ right:String)->some View { HStack {Text(left).foregroundStyle(C.muted);Spacer();Text(right).fontWeight(.medium)}.font(.custom("Inter",size:15)).padding(.vertical,15).overlay(alignment:.bottom){C.border.frame(height:1)} }
  private var proof:some View {
    VStack(spacing:0) {
      let order=m.orders.first(where:{$0.id == m.selectedOrderID}) ?? m.orders.first
      HStack {Color.clear.frame(width:40,height:40);Spacer();Text(order?.uploaded == true ? "Payment sent" : "Payment queued").font(.custom("Inter",size:16).weight(.semibold));Spacer();Button {m.screen = .home} label:{Image(systemName:"xmark").font(.custom("Inter",size:18)).frame(width:40,height:40).overlay(Circle().stroke(C.border))}}
      HStack(spacing:8){Image(systemName:order?.status == "settled" ? "checkmark" : "clock");Text(order?.status == "settled" ? "Confirmed on Arc" : "Pending settlement")}.font(.custom("Inter",size:13).weight(.medium)).foregroundStyle(order?.status == "settled" ? C.green : C.muted).padding(.horizontal,12).padding(.vertical,7).background(order?.status == "settled" ? Color(red:14/255,green:26/255,blue:19/255) : C.surface,in:Capsule()).overlay(Capsule().stroke(order?.status == "settled" ? Color(red:30/255,green:58/255,blue:42/255) : C.border)).padding(.top,32)
      Text("Show this to the vendor").font(.custom("Inter",size:26).weight(.semibold)).tracking(-0.8).padding(.top,16)
      Text("They can scan your signed payment.").font(.custom("Inter",size:15)).foregroundStyle(C.muted).padding(.top,6)
      if let order, let data=try? JSONEncoder().encode(order.send), let json=String(data:data,encoding:.utf8),let image=qr(json){Image(uiImage:image).interpolation(.none).resizable().frame(width:232,height:232).padding(18).background(C.fg,in:RoundedRectangle(cornerRadius:24)).padding(.top,26)}
      HStack(spacing:5){ForEach(0..<12,id:\.self){i in Capsule().fill(i<7 ? C.fg : Color(red:42/255,green:42/255,blue:47/255)).frame(width:18,height:4)}}.padding(.top,20)
      Text("Signed QR ready").font(.custom("Inter",size:13)).foregroundStyle(C.muted).padding(.top,10)
      Spacer()
      Button {m.screen = .home} label:{Text("Done").frame(maxWidth:.infinity).frame(height:54).background(C.surface,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(C.border)).font(.custom("Inter",size:16).weight(.semibold))}
    }.padding(.horizontal,24).padding(.top,8).padding(.bottom,24)
  }
  private var activity:some View {
    VStack(alignment:.leading,spacing:0) {HStack {Text("Activity").font(.custom("Inter",size:26).weight(.semibold));Spacer();Button {showAmounts.toggle()} label:{Image(systemName:showAmounts ? "eye.slash" : "eye")}.accessibilityLabel(showAmounts ? "Hide transaction amounts" : "Show transaction amounts");Button {Task {await m.sync()}} label:{Image(systemName:"arrow.clockwise")}.padding(.leading,12)}.padding(.top,16)
      if m.orders.isEmpty {Text("No payments yet").foregroundStyle(C.muted).padding(.top,24)}
      ScrollView {ForEach(m.orders){order in Button {m.selectedOrderID=order.id;m.screen = .proof} label:{VStack(alignment:.leading){orderRow(order);Text(order.status.replacingOccurrences(of:"_",with:" ").capitalized).font(.custom("Inter",size:12)).foregroundStyle(C.muted);if let error=order.error {Text(error).font(.custom("Inter",size:12)).foregroundStyle(C.muted)}}}.buttonStyle(.plain)}}
      Spacer()
    }.padding(.horizontal,24).safeAreaInset(edge:.bottom,spacing:0){bottomBar}
  }
  private var settings:some View {
    NavigationStack {Form {Section("Matcher") {TextField("http://Mac-IP:4173",text:$m.backend).textInputAutocapitalization(.never).autocorrectionDisabled();Button("Connect and sync") {Task {await m.setBackend(m.backend);m.showingSettings=false}}}
      Section("Wallet") {Text(m.address).font(.caption).textSelection(.enabled);HStack{Text("Arc escrow");Spacer();Text(CheckoutModel.money(m.balance)+" USDC")};HStack{Text("Wallet funds");Spacer();Text(CheckoutModel.money(m.walletBalance)+" USDC")};Button("Refresh balance") {Task {await m.refreshBalance()}};Button("Import testnet recovery key") {m.showingSettings=false;m.showingImport=true};Button("Show recovery key") {m.recoveryKey=SecureWallet.read() ?? ""}}
      if !m.recoveryKey.isEmpty {Section("Keep this private") {Text(m.recoveryKey).font(.caption).textSelection(.enabled)}}
      Section("Prepay escrow") {TextField("Amount in USDC",text:$depositAmount).keyboardType(.decimalPad);Button("Deposit to Arc escrow") {Task {await m.deposit(depositAmount);depositAmount=""}};Text("Deposits use this wallet’s Arc Testnet USDC. Keep a little for network fees.").font(.caption).foregroundStyle(C.muted)}
    }.navigationTitle("Settings").toolbar{ToolbarItem(placement:.topBarTrailing){Button("Done"){m.recoveryKey="";m.showingSettings=false}}}}
  }
  private var importSheet:some View {
    NavigationStack {Form {SecureField("0x private key",text:$imported).textInputAutocapitalization(.never).autocorrectionDisabled();Button("Import wallet") {Task {await m.importKey(imported);imported=""}}}.navigationTitle("Import wallet").toolbar{ToolbarItem(placement:.topBarTrailing){Button("Done"){m.showingImport=false}}}}
  }
  private func short(_ value:String)->String {value.count>12 ? String(value.prefix(6))+"…"+String(value.suffix(4)) : value}
  private func qr(_ text:String)->UIImage? {let filter=CIFilter.qrCodeGenerator();filter.message=Data(text.utf8);filter.correctionLevel="L";guard let output=filter.outputImage,let cg=CIContext().createCGImage(output,from:output.extent) else{return nil};return UIImage(cgImage:cg)}
}
