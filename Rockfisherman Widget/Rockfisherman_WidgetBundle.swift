//
//  Rockfisherman_WidgetBundle.swift
//  Rockfisherman Widget
//
//  Created by Steven White on 25/09/2025.
//

import WidgetKit
import SwiftUI

@main
struct Rockfisherman_WidgetBundle: WidgetBundle {
    var body: some Widget {
        Rockfisherman_Widget()
        Rockfisherman_WidgetControl()
        Rockfisherman_WidgetLiveActivity()
    }
}
