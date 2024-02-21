//
//  PythonObjectExtension.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/17.
//

import Foundation
import PythonKit
import Python

extension PythonObject {
    
//    func callFunction(name: String, withArguments args: [PythonConvertible]) -> PythonObject? {
//        autoreleasepool {
//            
//            guard let dvrFo = Resolve.shared.sys?.modules["fusionscript"].scriptapp("Resolve").checking[dynamicMember: "GetProjectManager"],
//                  let pm = try? dvrFo.throwing.dynamicallyCall(withArguments: []),
//                  let _ = pm.checking[dynamicMember: "GetCurrentProject"]
//            else {
//                print("Resolve may be quit.")
//                return nil
//            }
//            
//            guard let functionObject = self.checking[dynamicMember: name] else {
//                print("Could not access PythonObject member \(name)")
//                return nil
//            }
//            
//            do {
//                
//                let data = try functionObject.throwing.dynamicallyCall(withArguments: args)
//                
//                return data
//                
//            } catch {
//                let pythonError = error as? PythonError
//                let localizedDescription = pythonError?.description ?? error.localizedDescription
//                print(localizedDescription)
//                return nil
//            }
//        }
//    }
    
}
