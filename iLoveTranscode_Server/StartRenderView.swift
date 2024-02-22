//
//  StartRenderView.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/20.
//

import SwiftUI

struct StartRenderView: View {
    
    @ObservedObject private var viewModel: ContentView.ViewModel = .shared
    @State var selectedJobs: Set<String> = Set<String>()
    @Binding var dismiss: Bool
    
    var body: some View {
        VStack {
            Text("请选择需要渲染的任务")
                .font(.system(size: 18, weight: .bold))
            //                .padding([.top, .horizontal])
            List(viewModel.renderJobsSelectionList.values.sorted(by: { $0.order < $1.order }), id: \.jobID) { job in
                HStack {
                    Image(systemName: selectedJobs.contains(job.jobID) ? "checkmark.circle" : "xmark.circle")
                    Image(systemName: "briefcase")
                    Text(job.jobName)
                    Image(systemName: "filemenu.and.selection")
                    Text(job.timelineName)
                    Spacer()
                    Text(job.status.string)
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedJobs.contains(job.jobID) {
                        selectedJobs.remove(job.jobID)
                    } else {
                        selectedJobs.insert(job.jobID)
                    }
                }
                .foregroundStyle(selectedJobs.contains(job.jobID) ? .green : .secondary)
            }
            .scrollContentBackground(.hidden)
            
            HStack {
                Spacer()
                
                Button(action: {
                    dismiss.toggle()
                }, label: {
                    Image(systemName: "xmark")
                        .padding([.leading, .vertical])
                    Text("取消")
                        .padding([.trailing, .vertical])
                })
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: {
                    viewModel.startRenderJobs(jobIds: Array(selectedJobs))
                    dismiss.toggle()
                }, label: {
                    Image(systemName: "play")
                        .padding([.leading, .vertical])
                    Text(viewModel.renderJobsButtonDisabled ? "正在渲染" : "开始渲染")
                        .padding([.trailing, .vertical])
                })
                .tint(.green)
                .disabled(viewModel.renderJobsButtonDisabled || selectedJobs.isEmpty)
                .padding(.horizontal)
                .buttonStyle(.borderless)
                
                Spacer()
            }
        }
        .padding(.top)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    StartRenderView(dismiss: .constant(true))
}
