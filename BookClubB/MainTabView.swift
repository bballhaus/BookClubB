//
//  MainTabView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                HomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            NavigationView {
                GroupPageView()
            }
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Groups")
            }

            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
                Text("Profile")
            }
        }
    }
}

#Preview {
    MainTabView()
}
