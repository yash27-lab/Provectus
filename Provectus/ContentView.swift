//
//  ContentView.swift
//  Provectus
//
//  Created by yash negi on 2/8/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: ProvectusDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(ProvectusDocument()))
}
