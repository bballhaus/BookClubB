//
//  MainTabView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: - Home Tab
            NavigationView {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // MARK: - Groups Tab
            NavigationView {
                GroupPageView()
            }
            .tabItem {
                Label("Groups", systemImage: "person.3.fill")
            }
            .tag(1)

            // MARK: - Profile Tab
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
