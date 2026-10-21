//
//  MainTabView.swift
//  CourtLink
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @State private var selectedTab: Int = 0
    /// One shared GPS source for every customer screen (nearest courts, map, home).
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            if dataStore.isOwnerMode {
                // MARK: - Owner Mode Tabs
                OwnerDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.xaxis")
                    }
                    .tag(0)
                
                OwnerManageFacilityView()
                    .tabItem {
                        Label("My Facilities", systemImage: "building.2.fill")
                    }
                    .tag(1)
                
                OwnerFaultsView()
                    .tabItem {
                        Label("Faults", systemImage: "exclamationmark.triangle.fill")
                    }
                    .tag(2)
                
                MyBookingsView()
                    .tabItem {
                        Label("Reservations", systemImage: "calendar.badge.checkmark")
                    }
                    .tag(3)
                
                OwnerProfileView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            } else {
                // MARK: - Customer / Player Mode Tabs
                SportSelectionView()
                    .tabItem {
                        Label("Explore", systemImage: "sportscourt.fill")
                    }
                    .tag(0)
                
                FacilityMapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .tag(1)
                
                MyBookingsView()
                    .tabItem {
                        Label("My Bookings", systemImage: "calendar.badge.clock")
                    }
                    .tag(2)
                
                CustomerProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
            }
        }
        .tint(CourtLinkTheme.primaryGreen)
        .environmentObject(locationService)
        .onAppear {
            if !dataStore.isOwnerMode { locationService.request() }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(CourtLinkDataStore())
}
