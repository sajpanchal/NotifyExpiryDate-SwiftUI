//
//  CustomNotification.swift
//  NotifyExpiryDate
//
//  Created by saj panchal on 2021-10-02.
//

import Foundation
import UserNotifications
import CoreData
import CloudKit

class CustomNotification: ObservableObject {
    
    @Published var isNotificationEnabled: Bool = !UserDefaults.standard.bool(forKey: "isNotificationDisabled")
    var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }
    
    init() {
        isNotificationEnabled = !UserDefaults.standard.bool(forKey: "isNotificationDisabled")
    }
    
   func checkExpiry(expiryDate: Date, deleteAfter: Int, product: Product) -> String {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate)
            if let days = diff.day {
     
                // Expiry date is passed
                if days < 0 {
                    // deletion days are passed.
                    if abs(days) >= deleteAfter {
                        return "Delete"
                    }
                    //deletion days are yet to be passed.
                    else {
                        return "Expired"
                    }
                }
                // Expiry date is not passed yet.
                else {
                    // expiry date is 3 or less days away.
                    if days <= product.redZoneExpiry {
                        if self.isNotificationEnabled {
                         //   print("calling notifcation for \(product.getName)")
                        }
                        return "Near Expiry"
                    }
                    else if days <= product.yellowZoneExpiry && days > product.redZoneExpiry {
                        return "Far From Expiry"
                    }
                    else {
                        return "Alive"
                    }
                }
            }
        return "Undefined"
    }
    
    func notificationRequest() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert,.badge, .sound]) { success, error in
                if success {
                    print("Notification request has been set for user to authorize.")
                }
                else if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
            
    func sendTimeNotification(product: Product) {
        let timeInterval = Calendar.current.dateComponents([.second], from: Date(), to: product.expiryDate!)
       
        let addRequest =  { (seconds: Int) -> Void in
            let content = UNMutableNotificationContent()
            content.title = "Expiry Date Reminder"
            if seconds == 0 {
                content.body = "Your product '\(product.getName)' has been expired today!"
            }
            else if seconds == 86400 {
                content.body = "Your product '\(product.getName)' is expiring tommorrow!"
            }
            else if seconds == 2*86400 {
                content.body = "Your product '\(product.getName)' is expiring in 2 days!"
            }
            else {
                content.body = "Your product '\(product.getName)' is expiring on \(product.ExpiryDate.capitalized)!"
            }
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeInterval.second! - seconds), repeats: false)
            let request = UNNotificationRequest(identifier: "\(product.getProductID)\(seconds)", content: content, trigger: trigger)
        
            UNUserNotificationCenter.current().add(request) { error in
                guard let error = error else {
                    return
                }
                fatalError(error.localizedDescription)
            }
        }
      
    
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .authorized {
                    print("----------------Notifications for \(product.getName)----------------")
                    for i in 0...product.redZoneExpiry {
                       if timeInterval.second! > i*86400 {
                        addRequest(i*86400)
                        }
                    }
                }
                else if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                    print("Notification request is not authorized by the user yet.")
                        
                        if success {
                            for i in 0...product.redZoneExpiry {
                            if timeInterval.second! > i*86400 {
                            addRequest(i*86400)
                            }
                        }
                       
                        print("Notification request has been now sent...")
                        }
                    else {
                            fatalError((error != nil) ? error!.localizedDescription : "Unknown Error." )
                        }
                    }
                }
                else {
                    return
                }
            }
    }
    
    func removeNotification(product: Product) {
        var productIDs: [String] = []
        for i in 0...product.redZoneExpiry {
            productIDs.insert("\(product.getProductID)\(i*86400)", at: i)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: productIDs)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: productIDs)
      
        print("product notification is deleted for \(product.getName) with id: \(product.getProductID)")
       
    }
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All product notification is deleted...")
    }
    
    func saveContext(viewContext: NSManagedObjectContext) {
        do {
            try viewContext.save()
            print("product is saved in cloudKit.")
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func handleProducts(viewContext: NSManagedObjectContext, result: String, product: Product) {
        switch result {
            //remove the product notification and delete from core data
            case "Delete" :
            removeNotification(product: product)
                viewContext.delete(product)
            self.saveContext(viewContext: viewContext)
            // once notification is sent
            case "Near Expiry":
            print("")
            case "Expired":
            removeNotification(product: product)
                break
        case "Alive":
            print("")
            default:
            break
        }
    }
    func listOfPendingNotifications() -> Int {
        var counts = 0
        UNUserNotificationCenter.current().getPendingNotificationRequests { (notifications) in
            print("number of pending notifications are \(notifications.count)")
            
            counts = notifications.count
            print("---------------List of Notifications----------------")
            for notification in notifications {
                print(notification.content.body)
            }
        }
        return counts
    }
    func modifyDate(date: Date) -> Date {
        let reminderTime = (UserDefaults.standard.object(forKey: "reminderTime") as? Date)!
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let reminderTimeString = timeFormatter.string(from: reminderTime)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: date)
        let modifiedDateStr = "\(dateStr), \(reminderTimeString)"
        print("Modified Date String is : \(modifiedDateStr)")
        formatter.timeStyle = .short
        let modifiedDate = formatter.date(from: modifiedDateStr)
        //print("modified date:\(String(describing: modifiedDate))")
        return modifiedDate ?? date
    }
    
    
}





/*
 var daysCount = 2
   if timeInterval.day! >= 180 {
       daysCount = 30
   }
   else if timeInterval.day! >= 30 {
       daysCount = 7
   }
   else {
       daysCount = 2
   }
 */
