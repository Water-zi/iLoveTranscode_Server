//
//  DeviceTokensView.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/29.
//

import SwiftUI

struct DeviceTokensView: View {
    
    @ObservedObject private var viewModel: ContentView.ViewModel = .shared
    @State var tokensInKeyChain: [String] = []
    @Binding var dismiss: Bool
    
    var body: some View {
        VStack {
            
            HStack {
                Text("通知设备列表")
                    .font(.system(size: 18, weight: .bold))
                Spacer(minLength: 0)
                Button(action: {
                    dismiss.toggle()
                }, label: {
                    Image(systemName: "xmark")
                    Text("关闭")
                })
                .buttonStyle(.borderless)
                
            }
            .padding(.horizontal)
            //                .padding([.top, .horizontal])
            List(viewModel.deviceTokens.sorted(), id: \.self) { token in
                HStack {
                    Image(systemName: "platter.filled.top.iphone")
                    Text(token.hideMiddle())
                    Spacer()
                    Button(action: {
                        TransmitEncryption.modifyDeviceToken(token: token, save: !tokensInKeyChain.contains(token)) { tokens in
                            self.tokensInKeyChain = tokens
                        }
                    }, label: {
                        Text(tokensInKeyChain.contains(token) ? "忘记" : "记住")
                            .foregroundStyle(tokensInKeyChain.contains(token) ? .red : .green)
                    })
                    .buttonStyle(.borderless)
                    if !tokensInKeyChain.contains(token) {
                        Button(action: {
                            viewModel.deviceTokens.remove(token)
                        }, label: {
                            Text("不再通知")
                                .foregroundStyle(.red)
                        })
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 5)
            }
            .scrollContentBackground(.hidden)
            .task {
                TransmitEncryption.getDeviceTokens { tokens in
                    DispatchQueue.main.async {
                        self.tokensInKeyChain = tokens ?? []
                    }
                }
            }
        }
        .padding(.top)
        .frame(width: 230, height: 200)
    }
}

#Preview {
    DeviceTokensView(dismiss: .constant(true))
}
