//
//  ContentView.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/4.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var viewModel = ViewModel.shared
    @State private var showPasswordAlert: Bool = UserDefaults.standard.object(forKey: "NotShowRequirePasswordReasonAlert") as? Bool ?? true
    @State private var showStartRenderQAView: Bool = false
    
    var isMenuView: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if isMenuView {
                HStack {
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Spacer()
                    Text("我爱转码·发射器")
                        .font(.system(size: 23, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.bottom, -8)
            } else {
                Text("我爱转码·发射器")
                    .font(.system(size: 23, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, -8)
            }
            
            VStack {
                Text("项目信息")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(spacing: 12) {
                    HStack {
                        Text("项目名称")
                        if Resolve.shared.davinciInstalled {
                            Text(viewModel.projectName.isEmpty ? "正在获取项目信息..." : viewModel.projectName)
                                .bold()
                                .task {
                                    guard Resolve.shared.currentProject == nil else { return }
                                    await viewModel.tryToGetProject(loop: true)
                                }
                        } else {
                            Text(viewModel.projectName.isEmpty ? "达芬奇未正确安装..." : viewModel.projectName)
                                .bold()
                                .foregroundStyle(.red)
                                .task {
                                    viewModel.showDaVinciResolveNotInstalledSheet = !Resolve.shared.davinciInstalled
                                }
                        }
                        Spacer()
                        if viewModel.canRetryGetProject {
                            Button(action: {
                                Task {
                                    await viewModel.tryToGetProject(loop: false)
                                }
                            }, label: {
                                Text("重试")
                                Image(systemName: "arrow.counterclockwise.circle")
                            })
                            .buttonStyle(.borderless)
                            .tint(.blue)
                        } else if !viewModel.projectName.isEmpty {
                            Button(action: {
                                viewModel.showStartRenderSelectionListView = true
                            }, label: {
                                Text(viewModel.renderJobsButtonDisabled ? "正在渲染" : "开始渲染")
                            })
                            .disabled(viewModel.renderJobsButtonDisabled)
                            .buttonStyle(.borderless)
                            .tint(viewModel.renderJobsButtonDisabled ? .green : .blue)
                            .sheet(isPresented: $viewModel.showStartRenderSelectionListView, onDismiss: {
                                viewModel.renderJobsSelectionList.removeAll()
                            }, content: {
                                StartRenderView()
                            })
                            
                            Button(action: {
                                showStartRenderQAView.toggle()
                            }, label: {
                                Image(systemName: "questionmark.circle")
                            })
                            .tint(.secondary)
                            .buttonStyle(.borderless)
                            .popover(isPresented: $showStartRenderQAView, arrowEdge: .trailing, content: {
                                VStack(spacing: 5) {
                                    Text("为什么在这里开始渲染？")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("使用\"我爱转码·发射器\"启动渲染任务，可以避免渲染失败时因错误弹窗导致UI卡死，而无法及时获取到任务失败信息的问题。")
                                        .frame(width: 280)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(10)
                                }
                                .padding()
                            })
                        }
                    }
                    
                }
            }
            VStack {
                Text("服务器信息")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                Divider()
                    .padding(.bottom, 5)
                VStack(spacing: 12) {
                    HStack {
                        Picker(selection: $viewModel.selectedBlocker.didSet(execute: { newValue in
                            guard newValue != .Custom else {
                                viewModel.connectedToMQTTServer = .disconnected
                                return
                            }
                            viewModel.connectToMQTTBlocker()
                        })) {
                            ForEach(viewModel.mqttBlockers) { blocker in
                                Text(blocker.name)
                                    .tag(blocker)
                            }
                        } label: {
                            Text("选择MQTT服务器")
                        }
                        Image(systemName: "circle.fill")
                            .foregroundStyle(viewModel.connectedToMQTTServer.color)
                    }
                    if viewModel.selectedBlocker == .Custom {
                        HStack {
                            Text("服务器地址")
                            TextField(text: $viewModel.customBlockerAddress) {
                                Text("address.blocker.com")
                            }
                            .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("端口")
                            TextField(text: $viewModel.customBlockerPort) {
                                Text("1883")
                            }
                            .frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                            Toggle(isOn: $viewModel.usingTLS.didSet(execute: { newValue in
                                if newValue == true {
                                    viewModel.showAlertOfUsingTLS = true
                                }
                            }), label: {
                                Text("使用TLS")
                            })
                            .alert("TLS大概率是不受支持的", isPresented: $viewModel.showAlertOfUsingTLS, actions: {
                                Button(action: {
                                    viewModel.usingTLS = true
                                }, label: {
                                    Text("仍然使用")
                                })
                                
                                Button(action: {
                                    viewModel.usingTLS = false
                                }, label: {
                                    Text("取消")
                                })
                            }, message: {
                                Text("不建议使用TLS功能，除非您的服务器是完全可控的。")
                            })
                            Spacer()
                            Button(action: {
                                
                            }, label: {
                                Text("测试")
                            })
                        }
                    }
                }
            }
            
            VStack {
                Text("推送服务器信息")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(spacing: 12) {
                    HStack {
                        Text("设备密钥")
                        if let _ = viewModel.deviceToken {
                            Text(viewModel.getDeviceTokenString())
                        } else {
                            Text("请在APP中添加或打开项目...")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        Text("活动密钥")
                        if let _ = viewModel.activityToken {
                            Text(viewModel.getActivityTokenString())
                        } else {
                            Text("请在APP的项目里订阅通知...")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            
            VStack {
                HStack {
                    Text("项目二维码")
                    Spacer()
                    Text("请使用\"我爱转码\"APP扫描")
                }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
                Divider()
                if let cgImage = viewModel.qrCodeImage {
                    Image(cgImage, scale: 1, label: Text("Project QRCode"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Spacer()
                    Text("二维码将在发射器获取到所有信息后生成")
                        .bold()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            
            VStack {
                Divider()
                HStack {
                    Text("Developed by Water-Zi")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }, label: {
                        HStack(spacing: 0) {
                            Image(systemName: "command")
                            Text("Q 退出")
                        }
                        .font(.system(size: 12))
                    })
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.top, -10)
        }
        .alert("达芬奇未正确安装...", isPresented: $viewModel.showDaVinciResolveNotInstalledSheet, actions: {
            Button("好的", role: .cancel) { }
            Button("退出", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }, message: {
            Text("""
            该软件从达芬奇软件读取数据并上传，以供用户远程查看其渲染任务的进度。但当前APP无法与达芬奇进行通信。
            
            ===请注意检查以下事项===
            
            ·是否已安装并启动达芬奇主程序·
            ·主程序是否正确安装在默认位置·
            ·外部脚本使用是否已设置为本地·
            """)
        })
        .padding(.horizontal)
        .padding(.bottom, 8)
        .padding(.top, 10)
        .ignoresSafeArea(edges: .vertical)
        .frame(width: 300, height: viewHeight())
    }
    
    func viewHeight() -> CGFloat {
        if viewModel.selectedBlocker == .Custom {
            if isMenuView {
                return 680
            } else {
                return 650
            }
        } else {
            if isMenuView {
                return 610
            } else {
                return 580
            }
        }
    }
    
}

#Preview {
    ContentView(isMenuView: false)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

extension Binding {
    func didSet(execute: @escaping (Value) -> Void) -> Binding {
        return Binding(
            get: { self.wrappedValue },
            set: {
                self.wrappedValue = $0
                execute($0)
            }
        )
    }
}
