/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import Foundation
import CoreData

class CoreDataStack: CustomStringConvertible {
  var modelName : String
  var storeName : String
  var options : [String : AnyObject]?
  
  init(modelName:String, storeName:String, options: [String : AnyObject]? = nil) {
    self.modelName = modelName
    self.storeName = storeName
    self.options = options
  }
  
  var description : String {
    return "context: \(context)\n" +
      "modelName: \(modelName)" +
      "storeURL: \(storeURL)\n"
  }
  
  var modelURL : NSURL {
    return NSBundle.mainBundle().URLForResource(self.modelName, withExtension: "momd")!
  }
  
  var storeURL : NSURL {
    var storePaths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true) as [String]
    let storePath = String(storePaths[0]) as NSString
    let fileManager = NSFileManager.defaultManager()
    
    do {
      try fileManager.createDirectoryAtPath(storePath as String, withIntermediateDirectories: true, attributes: nil)
    } catch let error as NSError {
      print("Error creating storePath \(storePath): \(error)")
    }
    let sqliteFilePath = storePath.stringByAppendingPathComponent(storeName + ".sqlite")
    return NSURL(fileURLWithPath: sqliteFilePath)
  }
  
  lazy var model : NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: self.modelURL)!
  
  var store : NSPersistentStore?
  
  lazy var coordinator : NSPersistentStoreCoordinator = {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.model)
    do {
      self.store = try coordinator.addPersistentStoreWithType(
        NSSQLiteStoreType,
        configuration: nil,
        URL: self.storeURL,
        options: self.options)
    } catch var error as NSError {
      print("Store Error: \(error)")
      self.store = nil
    } catch {
      fatalError()
    }
    return coordinator
  }()
  
  lazy var context : NSManagedObjectContext = {
    let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    context.persistentStoreCoordinator = self.coordinator
    return context
  }()
    
    var updateContextWithUbiquitousContentUpdates: Bool = false {
        willSet {
            ubiquitousChangesObserver = newValue ?
            NSNotificationCenter.defaultCenter() : nil
        }
    }
    
    private var ubiquitousChangesObserver: NSNotificationCenter? {
        didSet {
            oldValue?.removeObserver(self, name: NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: coordinator)
            ubiquitousChangesObserver?.addObserver(self, selector: #selector(CoreDataStack.persistentStoreDidImportUbiquitousContentChanges(_:)), name: NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: coordinator)
        }
    }
    
    @objc func persistentStoreDidImportUbiquitousContentChanges(notification: NSNotification) {
        NSLog("Merging ubiquitous content changes")
        context.performBlock {
            self.context.mergeChangesFromContextDidSaveNotification(notification)
        }
    }
    
}
