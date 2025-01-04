//
//  ContentView.swift
//  KeepInTouch
//
//  Created by Nikhil Kakarla on 8/28/24.
//

import SwiftUI
import Foundation
import Combine

struct ContentView: View {
    @State private var loggedIn = true
    @ObservedObject private var contactStore: ContactStore  // Shared ContactStore with contactList
    //TODOCHANGE LOGGEDIN
    
    @ObservedObject var homeScreenViewModel: HomeScreenViewModel
    @ObservedObject var swiperViewModel: SwiperViewModel
    
    init() {
        // Initialize the view models with ContactsStore's contacts list
        self.contactStore = ContactStore.shared
        let contacts = loadContacts()
        
        checkBackUp()
        self.homeScreenViewModel = HomeScreenViewModel(contacts: contacts)
        self.swiperViewModel = SwiperViewModel(contacts: contacts)
        
    }
    
    var body: some View {
        if !loggedIn {
            LoginView(loggedIn: $loggedIn)
        } else {
            TabView {
                HomeView(homeScreenViewModel: homeScreenViewModel)
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                AskAI()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("Ask AI")
                    }
//                FindSomeone(swiperViewModel: swiperViewModel)
//                    .tabItem {
//                        Image(systemName: "chevron.right.circle.fill")
//                        Text("Swiper")
//                    }
                AllContactsView(/*contactStore: contactStore*/)
                    .tabItem {
                        Image(systemName: "person.fill.checkmark")
                        Text("All Contacts")
                    }
                RecentPhotosView(/*contactsStore: contactStore*/)
                    .tabItem {
                        Image(systemName: "camera")
                        Text("Recent Pics")
                    }
                Settings(loggedIn: $loggedIn)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
        }
    }
}
