//
//  MainTabView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//
//  Updated to call ProfileView() without arguments since it no longer takes any.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Home Tab
            NavigationView {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            // Groups Tab
            NavigationView {
                GroupPageView()
            }
            .tabItem {
                Label("Groups", systemImage: "person.3.fill")
            }
            .tag(1)
            
            // Personal Profile View
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
        }
    }
}

#Preview {
    MainTabView()
}
