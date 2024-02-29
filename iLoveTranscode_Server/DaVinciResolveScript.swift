//
//  DaVinciResolveScript.swift
//  TVCAutomator
//
//  Created by 唐梓皓 on 2024/1/12.
//

import Foundation
import PythonKit
import Python

class Resolve: NSObject {
    static let shared: Resolve = Resolve()
    public var noneObject: PythonObject?
    public var sys: PythonObject?
    public var dvr: PythonObject?
    public var projectManager: PythonObject?
    public var currentProject: PythonObject?
    
    public var davinciInstalled: Bool = false
    
    public var wrappedProject: PythonObject? {
        if currentProject == noneObject {
            return nil
        } else {
            return currentProject
        }
    }
    
    override init() {
        super.init()
        guard let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil) else { return }
        guard let libDynloadPath = Bundle.main.path(forResource: "python-stdlib/lib-dynload", ofType: nil) else { return }
        setenv("PYTHONHOME", stdLibPath, 1)
        setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath)", 1)
        Py_Initialize()
        davinciInstalled = false
        noneObject = Python.None
//        let app = ResolveApp.shared
//        app.newApp()
        loadDavinciResolveScript()
        
    }
    
    func loadDavinciResolveScript() {
        sys = Python.import("sys")
        //        let os = Python.import("os")
        let libutil = Python.import("importlib.util")
        sys?.path.append("/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/")
        let resolveLibPath = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
        let spec = libutil.spec_from_file_location("fusionscript", resolveLibPath)
        do {
            guard let function = libutil.checking[dynamicMember: "module_from_spec"],
                  let script_module = try? function.throwing.dynamicallyCall(withArguments: [spec]),
                  let function2 = spec.loader.checking[dynamicMember: "exec_module"],
                  let _ = try? function2.throwing.dynamicallyCall(withArguments: [script_module])
            else {
                davinciInstalled = false
                return
            }
            davinciInstalled = true
        }
    }
    
}
