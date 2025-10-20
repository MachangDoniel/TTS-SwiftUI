//
//  LanguagePickerView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI

struct LanguagePickerView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showLanguageOptions = false
    @State private var selectedFilter: String? = nil // nil = all
    @State private var selectedLanguage: String? = nil // nil = all
    @FocusState private var isSearchFieldFocused: Bool
    
    // Sample data
    let voices: [Voice] = [
        Voice(name: "Anastasia", language: "English", accent: "US", mood: "Calm", type: "Free"),
        Voice(name: "Carlos", language: "Español", accent: "ES", mood: "Lively", type: "Premium"),
        Voice(name: "Emma", language: "English", accent: "UK", mood: "Friendly", type: "Premium"),
        Voice(name: "Nikolai", language: "Russian", accent: "RU", mood: "Calm", type: "Free"),
        Voice(name: "Sophia", language: "German", accent: "DE", mood: "Bright", type: "Free"),
        Voice(name: "Mia", language: "Danish", accent: "DK", mood: "Energetic", type: "Premium"),
        Voice(name: "Giovanni", language: "Italian", accent: "IT", mood: "Smooth", type: "Free"),
        Voice(name: "Lena", language: "Greek", accent: "GR", mood: "Warm", type: "Premium"),
        Voice(name: "Aarav", language: "Hindi", accent: "IN", mood: "Deep", type: "Free"),
        Voice(name: "Maria", language: "Español", accent: "MX", mood: "Soft", type: "Free"),
    ]
    
    let languages = ["English", "Español", "Danish", "German", "Greek", "Italian", "Russian", "Hindi"]
    
    // MARK: - Filtered voices
    var filteredVoices: [Voice] {
        voices.filter { voice in
            let matchesSearch = searchText.isEmpty ||
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.language.localizedCaseInsensitiveContains(searchText)
            
            let matchesLanguage = selectedLanguage == nil || voice.language == selectedLanguage
            let matchesType = selectedFilter == nil || voice.type == selectedFilter
            
            return matchesSearch && matchesLanguage && matchesType
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Top Bar
                    HStack(spacing: 12) {
                        if isSearching {
                            // 🔍 Active Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search", text: $searchText)
                                    .focused($isSearchFieldFocused)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            isSearchFieldFocused = true
                                        }
                                    }
                            }
                            .padding(8)
                            .background(Color(.systemGray6).opacity(0.2))
                            .cornerRadius(8)
                            
                            Button("Cancel") {
                                withAnimation {
                                    isSearching = false
                                    searchText = ""
                                    isSearchFieldFocused = false
                                }
                            }
                            .foregroundColor(.white)
                        } else {
                            // Normal Top Bar
                            Button(action: {
                                withAnimation { isSearching = true }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
//                            Spacer()
                            
                            // 🌐 Language Button
                            Button(action: {
                                withAnimation(.spring()) { showLanguageOptions.toggle() }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Language")
                                        .font(.headline)
                                    Image(systemName: showLanguageOptions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundColor(showLanguageOptions ? Color.blue: Color.white)
                                .background(showLanguageOptions ? Color.blue.opacity(0.20) : Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                            .foregroundColor(.white)
                            
//                            Spacer()
                            
                            // 💰 Free Filter
                            Button(action: {
                                withAnimation {
                                    if selectedFilter == "Free" {
                                        selectedFilter = nil // deselect
                                    } else {
                                        selectedFilter = "Free"
                                    }
                                }
                            }) {
                                Text("Free")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedFilter == "Free" ? Color.blue: Color.white)
                                    .background(selectedFilter == "Free" ? Color.blue.opacity(0.20) : Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.95))
                    
                    // MARK: - Language Options
                    if showLanguageOptions && !isSearching {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(languages, id: \.self) { lang in
                                    Button(action: {
                                        withAnimation {
                                            if selectedLanguage == lang {
                                                selectedLanguage = nil // deselect
                                            } else {
                                                selectedLanguage = lang
                                            }
                                        }
                                    }) {
                                        Text(lang)
                                            .font(.subheadline)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .foregroundColor(selectedLanguage == lang ? Color.blue : Color.white)
                                            .background(selectedLanguage == lang ? Color.blue.opacity(0.20) : Color(.systemGray6))
                                            .clipShape(Capsule())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - Content
                    if isSearching {
                        // Search Mode
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Features")
                                    .font(.title3)
                                    .bold()
                                    .padding(.horizontal)
                                    .foregroundColor(.white)
                                
                                ForEach(filteredVoices) { voice in
                                    Button {
                                        print("Selected: \(voice.name)")
                                    } label: {
                                        VoiceCard(voice: voice)
                                    }
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                    } else {
                        // Normal Mode
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedLanguage ?? "All Languages")
                                    .font(.title3)
                                    .bold()
                                    .padding(.horizontal)
                                    .foregroundColor(.white)
                                
                                if filteredVoices.isEmpty {
                                    Text("No voices found")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                } else {
                                    ForEach(filteredVoices) { voice in
                                        Button {
                                            print("Selected: \(voice.name)")
                                        } label: {
                                            VoiceCard(voice: voice)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
// MARK: - Preview
#Preview {
    LanguagePickerView()
}
