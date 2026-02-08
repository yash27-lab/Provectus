//
//  ProvectusApp.swift
//  Provectus
//
//  Created by yash negi on 2/8/26.
//

import SwiftUI

@main
struct ProvectusApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ProvectusDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
