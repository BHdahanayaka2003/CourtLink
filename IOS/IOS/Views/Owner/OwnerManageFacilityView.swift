//
//  OwnerManageFacilityView.swift
//  CourtLink
//
//  Facility & Court Management Hub for Venue Owners.
//  Allows adding new stadiums, adding courts to existing stadiums,
//  and syncing all updates to Firebase Firestore.
//

import SwiftUI

struct OwnerManageFacilityView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    
    @State private var showAddStadiumSheet: Bool = false
    @State private var facilityToEdit: Facility? = nil
    @State private var facilityToDelete: Facility? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var courtAddedFeedback: String = ""
    @State private var faultTarget: FaultTarget? = nil
    @State private var pinTarget: CourtPinTarget? = nil
    
    // Optional focus facility passed from dashboard
    var initialFacility: Facility? = nil
    
    init(facility: Facility? = nil) {
        self.initialFacility = facility
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Banner with "+ Add New Stadium / Facility" Button
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Facility Management")
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                Text("Manage your courts, add new venues, and update rates live in Firestore.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        // Dedicated "+ Add New Stadium" Button (Requested by User)
                        Button(action: {
                            showAddStadiumSheet = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("+ Add New Stadium / Facility")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(CourtLinkTheme.orangeButtonGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: CourtLinkTheme.accentOrange.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(18)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // Court Added Feedback Toast (if any)
                    if !courtAddedFeedback.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(courtAddedFeedback)
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // List of Managed Stadiums / Facilities
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your Managed Stadiums (\(dataStore.ownerFacilities.count))")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(dataStore.ownerFacilities) { facility in
                            OwnerFacilityCard(
                                facility: facility,
                                isActive: dataStore.ownerFacilityId == facility.id,
                                onAddCourt: {
                                    withAnimation {
                                        dataStore.addCourt(to: facility.id)
                                        courtAddedFeedback = "Added new court to \(facility.name)! Total: \(facility.courtsCount + 1) courts."
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        courtAddedFeedback = ""
                                    }
                                },
                                onEdit: {
                                    facilityToEdit = facility
                                },
                                onSelectActive: {
                                    dataStore.ownerFacilityId = facility.id
                                },
                                onDelete: {
                                    facilityToDelete = facility
                                    showDeleteAlert = true
                                },
                                onReportFault: { number in
                                    faultTarget = FaultTarget(facility: facility, courtNumber: number)
                                },
                                onPinCourt: { number in
                                    pinTarget = CourtPinTarget(facility: facility, courtNumber: number)
                                }
                            )
                        }
                    }
                    
                    Spacer(minLength: 30)
                }
                .padding(.vertical, 12)
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationTitle("Manage Stadiums")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddStadiumSheet) {
                AddEditFacilitySheet()
            }
            .sheet(item: $facilityToEdit) { facility in
                AddEditFacilitySheet(facility: facility)
            }
            .sheet(item: $faultTarget) { target in
                ReportFaultSheet(facility: target.facility, courtNumber: target.courtNumber)
            }
            .sheet(item: $pinTarget) { target in
                LocationPickerView(
                    title: "\(target.facility.sport.courtUnit) \(target.courtNumber) Position",
                    initial: dataStore.court(facilityId: target.facility.id, number: target.courtNumber)?.coordinate
                        ?? target.facility.coordinate,
                    onConfirm: { coordinate in
                        dataStore.setCourtLocation(facilityId: target.facility.id, number: target.courtNumber, coordinate: coordinate)
                    }
                )
            }
            .alert("Delete Stadium?", isPresented: $showDeleteAlert, presenting: facilityToDelete) { facility in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dataStore.deleteFacility(facilityId: facility.id)
                }
            } message: { facility in
                Text("Are you sure you want to remove \(facility.name) from database? All associated slots will also be removed.")
            }
        }
    }
}

// MARK: - Owner Facility Card with Courts and "+ Add Court" Button
struct OwnerFacilityCard: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    let facility: Facility
    let isActive: Bool
    let onAddCourt: () -> Void
    let onEdit: () -> Void
    let onSelectActive: () -> Void
    let onDelete: () -> Void
    let onReportFault: (Int) -> Void
    let onPinCourt: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Venue Top Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(facility.sport.badgeColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: facility.imageSystemName)
                        .font(.title2)
                        .foregroundColor(facility.sport.badgeColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(facility.name)
                            .font(.headline.bold())
                            .foregroundColor(.primary)
                        
                        if isActive {
                            Text("Active")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(CourtLinkTheme.primaryGreen)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text("\(facility.sport.rawValue) • \(facility.area) • \(facility.formattedPrice)/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit Details", systemImage: "pencil")
                    }
                    if !isActive {
                        Button(action: onSelectActive) {
                            Label("Set as Active Dashboard Venue", systemImage: "star.fill")
                        }
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Stadium", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
            
            Divider()
            
            // COURTS SECTION with dedicated "+ Add Court" Button (Requested by User)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Courts Available (\(facility.courtsCount))")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Dedicated "+ Add Court" Button
                    Button(action: onAddCourt) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption.bold())
                            Text("+ Add Court")
                                .font(.caption.bold())
                        }
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(10)
                    }
                }
                
                // Horizontal list of courts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1...max(facility.courtsCount, 1), id: \.self) { courtNum in
                            let courtId = Court.makeId(facilityId: facility.id, number: courtNum)
                            let status = dataStore.courtStatus(courtId)
                            Menu {
                                Text(Court.code(for: facility, number: courtNum))
                                Button { onReportFault(courtNum) } label: {
                                    Label("Report Fault", systemImage: "exclamationmark.triangle")
                                }
                                Button { onPinCourt(courtNum) } label: {
                                    Label("Set Exact Position on Map", systemImage: "mappin.and.ellipse")
                                }
                                if dataStore.customCourts[courtId] != nil {
                                    Button { dataStore.resetCourtLocation(facilityId: facility.id, number: courtNum) } label: {
                                        Label("Reset to Auto Position", systemImage: "arrow.uturn.backward")
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: status == .available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(status.color)
                                    Text("\(facility.sport.courtUnit) \(courtNum)")
                                        .font(.caption.bold())
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(status == .available ? Color(.systemGray6) : status.color.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Bottom Action Links
            HStack {
                Text("Hours: \(facility.openingHours)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Text("Edit Details")
                            .font(.caption.bold())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(CourtLinkTheme.accentOrange)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isActive ? CourtLinkTheme.primaryGreen.opacity(0.3) : Color.clear, lineWidth: 1.5)
                .padding(.horizontal)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    OwnerManageFacilityView()
        .environmentObject(CourtLinkDataStore())
}
