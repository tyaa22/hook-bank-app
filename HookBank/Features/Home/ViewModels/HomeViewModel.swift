import SwiftUI
import Core

@Observable
public final class HomeViewModel {
    public var activities: [Activity] = Activity.mockActivities
    
    public init() {}
    
    // In the future when using SwiftData, this class will likely take in a ModelContext 
    // or just rely on a @Query in the view. For now, it manages the mock data.
    
    public func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0)
    }
    
    public func deleteActivity(at offsets: IndexSet) {
        activities.remove(atOffsets: offsets)
    }
}
