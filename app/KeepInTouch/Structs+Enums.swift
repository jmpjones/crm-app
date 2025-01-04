//
//  Structs+Enums.swift
//  KeepInTouch
//
//  Created by Nikhil Kakarla on 10/31/24.
//

import Foundation
import NotificationCenter
import Combine
import SwiftUI
import CoreLocation

class ContactStore: ObservableObject {
    static let shared = ContactStore()  // Singleton instance
    
    @Published var contacts: [ProfessionalContact] = []
    @Published var recents: [ProfessionalContact] = []
    @Published var contactSoons: [ProfessionalContact] = []
    @Published var pinnedContacts: [ProfessionalContact] = []
    @Published var nearbyContacts: [ProfessionalContact] = []
    @Published var changed: Bool = false
    
    private init() {
        // Load initial contacts if needed
        contacts = loadContacts()
        recents = getCache(cacheType: .recents)
        contactSoons = rankByContactSoon()
        getNearbyContacts(contactList: contacts)
    }
    
    
    //CONTACT STORAGE FUCNTIONS
    func addContact(_ contact: ProfessionalContact) {
        contacts.append(contact)
        addRecent(contact: contact)
        getNearbyContacts(contactList: contacts)
        addAndSaveContact(contact: contact)
    }
    
    func removeContact(_ contact: ProfessionalContact) {
        contacts.removeAll { $0.id == contact.id }
        recents.removeAll { $0.id == contact.id }
        contactSoons.removeAll { $0.id == contact.id }
        nearbyContacts.removeAll { $0.id == contact.id }
        deleteContact(contact: contact)
    }
    
    func updateContact(_ contact: ProfessionalContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        }
        if let index = recents.firstIndex(where: { $0.id == contact.id }) {
            recents[index] = contact
        }
        if let index = contactSoons.firstIndex(where: { $0.id == contact.id }) {
            contactSoons[index] = contact
        }
        if let index = nearbyContacts.firstIndex(where: { $0.id == contact.id }) {
            nearbyContacts[index] = contact
        }
        
        getNearbyContacts(contactList: contacts)
        KeepInTouch.updateContact(contact: contact)
    }
    
    func loadContacts() -> [ProfessionalContact]{
        var contacts: [ProfessionalContact] = []
        pinnedContacts = []
        
        let defaults = UserDefaults.standard
        let contactIDs = defaults.array(forKey: "professionalContactIDs") as? [String] ?? []
        
        for contactID in contactIDs {
            let contactDict: Dictionary<String, Any> = defaults.dictionary(forKey: contactID) ?? [:]
            let imageData: String? = fetchLocalContactImage(contact_id: contactID)
            let newContact = ProfessionalContact(id: contactID,
                                                 name: contactDict["name"] as? String ?? "",
                                                 affiliaton: contactDict["affiliaton"] as? String ?? "",
                                                 phone: contactDict["phone"] as? String ?? "",
                                                 areaCode: contactDict["areaCode"] as? String ?? "+1",
                                                 email: contactDict["email"] as? String ?? "",
                                                 location: contactDict["location"] as? String ?? "",
                                                 locationCoords: stringToCoordinate(contactDict["locationCoords"] as? String ?? "") ?? nil,
                                                 lastContacted: contactDict["lastContacted"] as? String ?? "",
                                                 notes: contactDict["notes"] as? String ?? "",
                                                 picture_name: contactDict["picture_name"] as? String ?? "",
                                                 hasPicture: Bool(contactDict["hasPicture"] as? String ?? "false") ?? false,
                                                 imageData: imageData, //TODO: Change this
 //                                                imageData: contactDict["imageData"] as? String ?? nil,
                                                 
                                                 isFavorite: Bool(contactDict["isFavorite"] as? String ?? "false") ?? false,
                                                 birthday: contactDict["birthday"] as? String ?? "",
                                                 birthdayVerified: Bool(contactDict["birthdayVerified"] as? String ?? "false") ?? false,
                                                 daysUntilReminder: Int(contactDict["monthsUntilReminder"] as? String ?? String(DEFAULT_DAYS_TO_REMINDER)),
                                                 pinnedContact: Bool(contactDict["pinnedContact"] as? String ?? "false") ?? false,
                                                 
                                                 notificationListString: contactDict["notificationListString"] as? String ?? ""
                             )
            contacts.append(newContact)
            
            if newContact.pinnedContact {
                pinnedContacts.append(newContact)
            }
            
        }
        return contacts
    }
    
    func getNearbyContacts(contactList: [ProfessionalContact]){
        self.nearbyContacts.removeAll()
        getUserCoordinates { userLocation in
            if let userLocation = userLocation {
                for contact in contactList {
                    if let contactLocation = contact.locationCoords {
                        if withinRadius(addressCoordinates: contactLocation, userCoordinates: userLocation){
                            self.nearbyContacts.append(contact)
                        }
                    }
                }
            } else {
                print("Could not retrieve user's coordinates.")
            }
        }
    }
    
    func rankByContactSoon() -> [ProfessionalContact]{
        return Array(sortedContactsByOverdue(contacts: contacts).prefix(10))
    }

    
    //CACHE FUNCTIONS
    func addRecent(contact: ProfessionalContact) {
        // If the contact is already in the cache, move it to the front
        if let existingIndex = recents.firstIndex(where: { $0.id == contact.id }) {
            // Remove it from its current position
            recents.remove(at: existingIndex)
        }
        
        // Add the contact to the front of the cache
        recents.insert(contact, at: 0)
        
        // Optionally limit the cache size to prevent excessive memory usage
        if recents.count > CACHE_SIZE {
            recents.removeLast()  // Remove the least recently used contact if cache exceeds size
        }
        KeepInTouch.addToCache(contact: contact, cacheType: CacheType.recents)
    }
    
    func clearRecents() {
        recents.removeAll()
        deleteCache(cacheType: CacheType.recents)
    }
    
    func clearContactSoons() {
        contactSoons.removeAll()
        deleteCache(cacheType: CacheType.contactSoons)
    }
    
}



class ProfessionalContact: Identifiable, Codable, ObservableObject, Equatable {
    
    static func == (lhs: ProfessionalContact, rhs: ProfessionalContact) -> Bool {
        lhs.id == rhs.id
    }
    
    // Attributes for all contacts
    @Published var id: String
    @Published var name: String?
    @Published var affiliaton: String?
    @Published var phone: String? // ONLY SUPPORTS 10 DIGIT US NUMBERS FOR NOW
    @Published var areaCode: String?
    
    @Published var email: String?
    @Published var location: String?
    @Published var locationCoords: CLLocationCoordinate2D?
    @Published var lastContacted: String?
    @Published var notes: String?
    
    @Published var picture_name: String?
    @Published var hasPicture: Bool
    @Published var imageData: String?
    
    // Attributes for favorite contacts
    @Published var isFavorite: Bool = false
    @Published var birthday: String?
    @Published var birthdayVerified: Bool = false
    @Published var daysUntilReminder: Int?
    @Published var pinnedContact: Bool = false
    
    // Notifications
    @Published  var notificationList: [eventNotification]
    
    init(id: String? = nil, name: String, affiliaton: String? = nil, phone: String? = nil, areaCode: String? = nil, email: String? = nil, location: String? = nil, locationCoords: CLLocationCoordinate2D? = nil, lastContacted: String? = nil, notes: String? = nil, picture_name: String? = nil, hasPicture: Bool = false, imageData: String? = nil, isFavorite: Bool = false, birthday: String? = nil, birthdayVerified: Bool = false, daysUntilReminder: Int? = nil, pinnedContact: Bool = false, notificationListString: String = "") {
        
        self.id = id ?? UUID().uuidString
        self.name = name
        self.affiliaton = affiliaton
        self.phone = phone
        self.areaCode = areaCode
        self.email = email
        self.picture_name = picture_name
        self.hasPicture = hasPicture
        self.location = location
        self.locationCoords = locationCoords
        self.notes = notes
        self.lastContacted = lastContacted
        self.imageData = imageData
        
        self.isFavorite = isFavorite
        self.birthday = birthday
        self.birthdayVerified = birthdayVerified
        self.daysUntilReminder = daysUntilReminder
        self.pinnedContact = pinnedContact
        
        // Initialize notificationList with parsed string, if provided
        self.notificationList = ProfessionalContact.parseNotificationListString(notificationListString)
    }
    
    enum CodingKeys: String, CodingKey {
            case id, name, affiliaton, phone, areaCode, email, location, lastContacted, notes, picture_name, hasPicture, imageData, isFavorite, birthday, birthdayVerified, daysUntilReminder, pinnedContact, notificationList
        }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        affiliaton = try container.decodeIfPresent(String.self, forKey: .affiliaton)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        areaCode = try container.decodeIfPresent(String.self, forKey: .areaCode)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        lastContacted = try container.decodeIfPresent(String.self, forKey: .lastContacted)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        picture_name = try container.decodeIfPresent(String.self, forKey: .picture_name)
        hasPicture = try container.decode(Bool.self, forKey: .hasPicture)
        imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        birthdayVerified = try container.decodeIfPresent(Bool.self, forKey: .birthdayVerified) ?? false
        daysUntilReminder = try container.decodeIfPresent(Int.self, forKey: .daysUntilReminder)
        pinnedContact = try container.decodeIfPresent(Bool.self, forKey: .pinnedContact) ?? false
        notificationList = try container.decode([eventNotification].self, forKey: .notificationList)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(affiliaton, forKey: .affiliaton)
        try container.encode(phone, forKey: .phone)
        try container.encode(areaCode, forKey: .areaCode)
        try container.encode(email, forKey: .email)
        try container.encode(location, forKey: .location)
        try container.encode(lastContacted, forKey: .lastContacted)
        try container.encode(notes, forKey: .notes)
        try container.encode(picture_name, forKey: .picture_name)
        try container.encode(hasPicture, forKey: .hasPicture)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(birthdayVerified, forKey: .birthdayVerified)
        try container.encode(daysUntilReminder, forKey: .daysUntilReminder)
        try container.encode(pinnedContact, forKey: .pinnedContact)
        try container.encode(notificationList, forKey: .notificationList)
    }
    
    func setLocation(location: String?){
        self.location = location
        if let location = location{
            getCoordinateFromString(for: location) { coordinate, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                if let coordinate = coordinate {
                    self.locationCoords = coordinate
                    ContactStore.shared.updateContact(self)
                    
                } else {
                    print("No coordinates found.")
                }
            }
        }
        
        
    }

    func getPhone(includeAreaCode: Bool = true) -> String? {
        guard let phone = phone, phone != "None" else {
            return nil
        }
        
        let areaCode = phone.prefix(3)
        let middle = phone.dropFirst(3).prefix(3)
        let last = phone.suffix(4)

        var returnString = "(\(areaCode)) \(middle)-\(last)"
        if includeAreaCode {
            returnString = (self.areaCode ?? "+1") + " " + returnString
        }
        return returnString
    }
    
    func getNotificationString() -> String {
        if notificationList.isEmpty {
            return ""
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var result = ""
        
        for notification in self.notificationList {
            let dateString = dateFormatter.string(from: notification.date)
            result += "\(notification.id.uuidString): \(dateString): \(notification.reason) (Repeats: \(notification.repeatTime))\n"
        }
        
        return result
    }

    static private func parseNotificationListString(_ string: String) -> [eventNotification] {
        if string.isEmpty {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var notifications: [eventNotification] = []
        
        let lines = string.split(separator: "\n")
        
        for line in lines {
            let pattern = #"^(\S+): (.*?): (.*?) \(Repeats: (.*?)\)$"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            
            if let match = regex?.firstMatch(in: String(line), options: [], range: NSRange(location: 0, length: line.count)) {
                if let idRange = Range(match.range(at: 1), in: line),
                   let dateRange = Range(match.range(at: 2), in: line),
                   let reasonRange = Range(match.range(at: 3), in: line),
                   let repeatRange = Range(match.range(at: 4), in: line) {
                    
                    let idString = String(line[idRange])
                    let dateString = String(line[dateRange])
                    let reason = String(line[reasonRange])
                    let repeatTime = String(line[repeatRange])
                    
                    if let date = dateFormatter.date(from: dateString), let id = UUID(uuidString: idString) {
                        let notification = eventNotification(id: id, date: date, reason: reason, repeatTime: repeatTime)
                        notifications.append(notification)
                    }
                }
            }
        }
        
        return notifications
    }
}

struct eventNotification: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var reason: String
    var repeatTime: String
    
    init(id: UUID = UUID(), date: Date, reason: String, repeatTime: String) {
        self.id = id
        self.date = date
        self.reason = reason
        self.repeatTime = repeatTime
    }
    
    func getFormattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        
        return dateFormatter.string(from: self.date)
    }
}


struct UpcomingContactEvent: Identifiable {
    var id: UUID = UUID()
    var contact: ProfessionalContact
    var date: Date
    var type: EventType
    
    enum EventType : Equatable{
        case birthday
        case followUp
        case notification(String) // String to store notification reason
    }
}
