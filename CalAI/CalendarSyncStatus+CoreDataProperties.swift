import Foundation
import CoreData

extension CalendarSyncStatus {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CalendarSyncStatus> {
        return NSFetchRequest<CalendarSyncStatus>(entityName: "CalendarSyncStatus")
    }

    @NSManaged public var source: String?
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var syncToken: String?

}

extension CalendarSyncStatus : Identifiable {

}