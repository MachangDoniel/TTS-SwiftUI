//
//  TabBarView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct TabBarView: View {
    
    @State private var selectedTab: Int = 2
    @State private var showCamera: Bool = false
    @State private var image: UIImage?
    @State private var showBottomSheet: Bool = false
    
    var body: some View {
        
        // MARK: TabView
        TabView(selection: $selectedTab) {
            
            // MARK: Camera
            VStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding()
                    
                    // API Call with image
                }
            }
            .tabItem {
                Label("Camera", systemImage: "camera.fill")
            }
            .tag(1)
            
            Spacer()
            
            // MARK: Add
            VStack {
                Text("Add")
                    .font(.largeTitle)
                    .padding()
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(2)
            
            Spacer()
            
            // MARK: Account
            VStack {
                Text("Account")
                    .font(.largeTitle)
                    .padding()
            }
            .tabItem {
                Label("Account", systemImage: "person.circle.fill")
            }
            .tag(3)
            
        }
        .padding([.leading, .trailing], 20)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                showCamera = true
            } else if newValue == 2 {
                showBottomSheet = true
            }
            selectedTab = newValue
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in
                self.image = img
            }
        }
        .sheet(isPresented: $showBottomSheet) {
            BottomSheet(showBottomSheet: $showBottomSheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        
    }
}

#Preview {
    TabBarView()
}

