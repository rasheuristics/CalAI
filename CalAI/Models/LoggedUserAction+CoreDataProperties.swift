import Foundation
import CoreData

extension LoggedUserAction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LoggedUserAction> {
        return NSFetchRequest<LoggedUserAction>(entityName: "LoggedUserAction")
    }

    @NSManaged public var actionType: String?
    @NSManaged public var attendeeCount: Int16
    @NSManaged public var eventDuration: Double
    @NSManaged public var eventID: String?
    @NSManaged public var eventTitle: String?
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?

}

extension LoggedUserAction : Identifiable {

}
