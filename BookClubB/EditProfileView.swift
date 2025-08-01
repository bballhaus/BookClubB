//
//  EditProfileView.swift
//  BookClubB
//
// Created by Brooke Ballhaus on 5/31/25.
//


import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @State private var displayName: String
    @State private var profileImageURL: String?

    @State private var pickedUIImage: UIImage? = nil

    @State private var showingImagePicker = false

    let onSave: (_ newDisplayName: String, _ newImage: UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    init(initialDisplayName: String, initialImageURL: String?, onSave: @escaping (_: String, _: UIImage?) -> Void) {
        self._displayName = State(initialValue: initialDisplayName)
        self._profileImageURL = State(initialValue: initialImageURL)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // MARK: – Profile Image Section
                ZStack(alignment: .bottomTrailing) {
                    if let picked = pickedUIImage {
                        Image(uiImage: picked)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    }
                    else if let urlString = profileImageURL,
                            let url = URL(string: urlString),
                            !urlString.isEmpty
                    {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill.badge.exclamationmark")
                                            .foregroundColor(.red)
                                    )
                                    .frame(width: 120, height: 120)
                            @unknown default:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                            }
                        }
                    }
                    // 3) Otherwise, a placeholder
                    else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            )
                    }

                    // “Change Photo” button overlay:
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .offset(x: 6, y: 6)
                }
                .padding(.top, 40)

                // MARK: – Display Name TextField
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.headline)
                    TextField("Enter your display name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button (left)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                // Save button (right)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(displayName, pickedUIImage)
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoPicker(selectedImage: $pickedUIImage)
            }
        }
    }
}


struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> some UIViewController {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            guard let firstResult = results.first else { return }

            if firstResult.itemProvider.canLoadObject(ofClass: UIImage.self) {
                firstResult.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error {
                        print("Error loading image: \(error.localizedDescription)")
                        return
                    }
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.selectedImage = image
                        }
                    }
                }
            }
        }
    }
}
