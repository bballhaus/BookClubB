import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupPageView: View {
    // ── 1) Your existing @State vars ─────────────────────────────────
    @State private var allGroups: [BookGroup] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // ── 2) NEW: hold whatever the user types into the search bar ─────
    @State private var searchText: String = ""

    // Computed property for the current user’s UID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        NavigationView {
            VStack {
                // 1) Spinner while loading
                if isLoading {
                    ProgressView("Loading groups…")
                        .padding()
                }
                // 2) Any fetch error
                else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                // 3) If the user has typed in search, show filtered results
                else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchResultsView(
                        searchText: searchText,
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
                // 4) Otherwise, show the “New Group,” “Your Groups,”
                //    and “Groups You Might Be Interested In” UI (no extra header).
                else {
                    DefaultGroupsView(
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
            }
            .navigationTitle("Groups")
            // Force a large‐title so the search bar sits below it
            .navigationBarTitleDisplayMode(.large)
            // Attach the native iOS search bar right under “Groups”
            .searchable(
                text: $searchText,
                prompt: "Search all groups"
            ) {
                // (Optional) live dropdown suggestions
                ForEach(searchSuggestions, id: \.self) { suggestion in
                    Text(suggestion).searchCompletion(suggestion)
                }
            }
            .onAppear(perform: fetchAllGroups)
        }
    }

    // MARK: – dropdown suggestions (optional)
    private var searchSuggestions: [String] {
        let lower = searchText.lowercased()
        return allGroups
            .map { $0.title }
            .filter { $0.lowercased().contains(lower) }
            .prefix(5)
            .map { $0 }
    }

    // MARK: – Load all groups from Firestore
    private func fetchAllGroups() {
        guard Auth.auth().currentUser != nil else {
            self.errorMessage = "You must be signed in to view groups."
            return
        }

        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        db.collection("groups").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    return
                }

                guard let docs = snapshot?.documents else {
                    self.allGroups = []
                    return
                }

                // Convert each document into a BookGroup
                self.allGroups = docs.compactMap { doc in
                    BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                }
            }
        }
    }

    // MARK: – Join logic (used by SearchResultsView)
    private func joinGroup(_ group: BookGroup) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(group.id)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([user.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            if let err = err {
                print("Could not join: \(err.localizedDescription)")
            } else {
                fetchAllGroups()
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – DefaultGroupsView
// (No extra “Groups” header—just your “New Group,” “Your Groups,” and
//  “Groups You Might Be Interested In” sections exactly as before.)
// ───────────────────────────────────────────────────────────────────────

fileprivate struct DefaultGroupsView: View {
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    // “Your Groups” = all groups where the user’s UID is in memberIDs
    private var yourGroups: [BookGroup] {
        allGroups.filter { $0.memberIDs.contains(currentUserID) }
    }

    // “Other Groups” = all groups where the user is NOT already a member
    private var otherGroups: [BookGroup] {
        allGroups.filter { !$0.memberIDs.contains(currentUserID) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ─── “New Group” card (exactly as you had before) ───────────────
                NavigationLink(destination: CreateGroupView()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.95))
                            .frame(height: 120)

                        HStack(spacing: 16) {
                            Text("New Group")
                                .font(.title2)
                                .bold()
                                .padding(.leading)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .padding(.trailing)
                        }
                    }
                    .padding(.horizontal)
                }

                // ─── “Your Groups” horizontal scroller ───────────────────────────
                if !yourGroups.isEmpty {
                    SectionHeaderView(title: "Your Groups")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(yourGroups) { group in
                                GroupCardView(group: group)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // ─── “Groups You Might Be Interested In” horizontal scroller ────
                if !otherGroups.isEmpty {
                    SectionHeaderView(title: "Groups You Might Be Interested In")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(otherGroups) { group in
                                InterestGroupCircleView(
                                    group: group,
                                    onJoinComplete: onJoinComplete
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – SearchResultsView
// (When the user types in the search bar, show a vertical list of matches)
// ───────────────────────────────────────────────────────────────────────

fileprivate struct SearchResultsView: View {
    let searchText: String
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var matchingGroups: [BookGroup] {
        let lower = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return allGroups.filter { $0.title.lowercased().contains(lower) }
    }

    var body: some View {
        if matchingGroups.isEmpty {
            VStack {
                Spacer()
                Text("No groups found for “\(searchText)”")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(matchingGroups) { group in
                        HStack(spacing: 16) {
                            // Show each group’s cover (if group.imageUrl is valid),
                            // otherwise a gray circle placeholder
                            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                                switch phase {
                                case .empty:
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                case .failure:
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                        )
                                        .frame(width: 60, height: 60)
                                @unknown default:
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(group.memberIDs.count) member(s)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if group.memberIDs.contains(currentUserID) {
                                // Already a member → navigate to detail
                                NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            } else {
                                // Otherwise, show a Join button inline
                                JoinButtonInline(
                                    group: group,
                                    onJoinComplete: onJoinComplete
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – SectionHeaderView
// A simple header for each horizontal section (Your Groups, Other Groups)
// ───────────────────────────────────────────────────────────────────────

fileprivate struct SectionHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .padding(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .padding(.trailing)
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – GroupCardView
// Shows a large cover image + title for “Your Groups”
// ───────────────────────────────────────────────────────────────────────

fileprivate struct GroupCardView: View {
    let group: BookGroup

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                switch phase {
                case .empty:
                    // Placeholder rectangle while loading
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 200)
                        .cornerRadius(8)
                case .failure:
                    // Fallback if the URL is bad
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(.red)
                        )
                        .frame(width: 140, height: 200)
                @unknown default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 200)
                }
            }

            Text(group.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – InterestGroupCircleView
// Shows a circular cover + title + “Join”/“Joined” badge
// for “Groups You Might Be Interested In”
// ───────────────────────────────────────────────────────────────────────

fileprivate struct InterestGroupCircleView: View {
    let group: BookGroup
    let onJoinComplete: () -> Void

    @State private var joinInProgress = false
    @State private var showErrorAlert = false
    @State private var joinErrorMessage: String = ""

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                case .failure:
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        )
                        .frame(width: 80, height: 80)
                @unknown default:
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                }
            }

            Text(group.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 80)

            if group.memberIDs.contains(currentUserID) {
                Text("Joined")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Button(action: join) {
                    if joinInProgress {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                    } else {
                        Text("Join")
                            .font(.caption2)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                .disabled(joinInProgress)
                .alert(isPresented: $showErrorAlert) {
                    Alert(
                        title: Text("Could not join"),
                        message: Text(joinErrorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func join() {
        guard let user = Auth.auth().currentUser else { return }
        joinInProgress = true
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(group.id)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([user.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            joinInProgress = false
            if let err = err {
                joinErrorMessage = err.localizedDescription
                showErrorAlert = true
            } else {
                onJoinComplete()
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – JoinButtonInline
// A small inline “Join” button for the search results list
// ───────────────────────────────────────────────────────────────────────

fileprivate struct JoinButtonInline: View {
    let group: BookGroup
    let onJoinComplete: () -> Void

    @State private var isJoining = false
    @State private var showError = false
    @State private var errorText: String = ""

    var body: some View {
        Button(action: joinGroup) {
            if isJoining {
                ProgressView()
                    .scaleEffect(0.8, anchor: .center)
            } else {
                Text("Join")
                    .font(.caption2)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .disabled(isJoining)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Could not join"),
                message: Text(errorText),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func joinGroup() {
        guard let user = Auth.auth().currentUser else { return }
        isJoining = true
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(group.id)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([user.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            isJoining = false
            if let err = err {
                errorText = err.localizedDescription
                showError = true
            } else {
                onJoinComplete()
            }
        }
    }
}
