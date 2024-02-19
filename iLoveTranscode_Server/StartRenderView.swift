//
//  StartRenderView.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/20.
//

import SwiftUI

struct StartRenderView: View {
    
    @StateObject var viewModel: ContentView.ViewModel = .shared
    
    var body: some View {
        VStack {
            Text("请选择需要渲染的任务")
                .font(.system(size: 18, weight: .bold))
            //                .padding([.top, .horizontal])
            
            List(viewModel.renderJobsSelectionList.values.sorted(by: { $0.order < $1.order }), id: \.jobID) { job in
                HStack {
                    Image(systemName: job.selected ? "checkmark.circle" : "xmark.circle")
                    Image(systemName: "briefcase")
                    Text(job.jobName)
                    Image(systemName: "filemenu.and.selection")
                    Text(job.timelineName)
                    Spacer()
                    Text(job.status.string)
                }
                .onTapGesture {
                    viewModel.toggleRenderJobSelection(for: job)
                }
                .foregroundStyle(job.selected ? .green : .secondary)
            }
            .scrollContentBackground(.hidden)
            
            HStack {
                Spacer()
                
                Button(action: {
                    viewModel.showStartRenderSelectionListView = false
                }, label: {
                    Image(systemName: "xmark")
                        .padding([.leading, .vertical])
                    Text("取消")
                        .padding([.trailing, .vertical])
                })
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: {
                    viewModel.startRenderJobs()
                }, label: {
                    Image(systemName: "play")
                        .padding([.leading, .vertical])
                    Text(viewModel.renderJobsButtonDisabled ? "正在渲染" : "开始渲染")
                        .padding([.trailing, .vertical])
                })
                .tint(.green)
                .disabled(viewModel.renderJobsButtonDisabled || viewModel.renderJobsSelectionList.values.filter({ $0.selected }).isEmpty)
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
    StartRenderView()
}
