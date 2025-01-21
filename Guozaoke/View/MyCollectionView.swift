//
//  MyCollectionView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

enum MyTopicEnum {
    case collections
    case follows
    case browse
}


struct MyCollectionView: View {
    let topic : MyTopicEnum

    var body: some View {
        Text("Hello, World!")
    }
}
