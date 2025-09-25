import Foundation
import CoreData

extension CachedEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedEvent> {
        return NSFetchRequest<CachedEvent>(entityName: "CachedEvent")
    }

    @NSManaged public var eventId: String?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var location: String?
    @NSManaged public var eventDescription: String?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var source: String?
    @NSManaged public var organizer: String?
    @NSManaged public var calendarId: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var lastModified: Date?

}

extension CachedEvent : Identifiable {

}