//
//  OutgoingMessages.swift
//  PenPals
//
//  Created by Tim Van Cauwenberge on 3/29/20.
//  Copyright © 2020 SeniorProject. All rights reserved.
//

import Foundation

class OutgoingMessages {
    
    var messageDictionary: NSMutableDictionary
        
        //MARK: Initializers
        //text message
    init(message: String, senderId: String, senderName: String, date: Date, status: String, type: String) {
            
            // intialize dictionary
            messageDictionary = NSMutableDictionary(objects: [message, senderId, senderName, dateFormatter().string(from: date), status, type], forKeys: [kMESSAGE as NSCopying, kSENDERID as NSCopying, kSENDERNAME as NSCopying, kDATE as NSCopying, kSTATUS as NSCopying, kTYPE as NSCopying])
        }
        //picture message
        init(message: String, pictureLink: String, senderId: String, senderName: String, date: Date, status: String, type: String) {
            // intialize dictionary
            messageDictionary = NSMutableDictionary(objects: [message, pictureLink, senderId, senderName, dateFormatter().string(from: date), status, type], forKeys: [kMESSAGE as NSCopying, kPICTURE as NSCopying, kSENDERID as NSCopying, kSENDERNAME as NSCopying, kDATE as NSCopying, kSTATUS as NSCopying, kTYPE as NSCopying])
        }
        //video message
        init(message: String, video: String, thumbNail: NSData, senderId: String, senderName: String, date: Date, status: String, type: String) {
            
            let picThumb = thumbNail.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            // intialize dictionary
            messageDictionary = NSMutableDictionary(objects: [message, video, picThumb, senderId, senderName, dateFormatter().string(from: date), status, type], forKeys: [kMESSAGE as NSCopying, kVIDEO as NSCopying, kPICTURE as NSCopying, kSENDERID as NSCopying, kSENDERNAME as NSCopying, kDATE as NSCopying, kSTATUS as NSCopying, kTYPE as NSCopying])
        }
        
        
        //MARK: Create Message
        func createMessage(chatRoomID: String, messageDictionary: NSMutableDictionary, memberIds: [String], membersToPush: [String]) {

            //generate unique ID for chat that will never be repeated
            let messageId = UUID().uuidString
            messageDictionary[kMESSAGEID] = messageId
            
            //loop to get all the members in the "chatroom"
            for memberId in memberIds {
                //create "Message" in firebase
                // creates a message copy for each person in chatroom
                FirebaseReference(.Messages).document(memberId).collection(chatRoomID).document(messageId).setData(messageDictionary as! [String : Any])
            }
            //update recent to display the latest message
            updateRecents(chatRoomId: chatRoomID, lastMessage: messageDictionary[kMESSAGE] as! String)
            
            //send oush notifications
            var message: String
            
            message = NSLocalizedString("Select Language", comment: "")
            let pushText = "[  \(messageDictionary[kTYPE] as! String) \(message)]"
            
            sendPushNotification(memberToPush: membersToPush, message: pushText)
        }

        
        class func deleteMessage(withId: String, chatRoomId: String) {
           
            FirebaseReference(.Messages).document(FUser.currentId).collection(chatRoomId).document(withId).delete()
        }
        
        class func updateMessage(withId: String, chatRoomId: String, memberIds: [String]) {

            let readDate = dateFormatter().string(from: Date())
            
            let values = [kSTATUS : kREAD, kREADDATE : readDate]
            
            for userId in memberIds {
                
                FirebaseReference(.Messages).document(userId).collection(chatRoomId).document(withId).getDocument { (snapshot, error) in
                    
                    guard let snapshot = snapshot  else { return }
                    
                    if snapshot.exists {
                        
                        FirebaseReference(.Messages).document(userId).collection(chatRoomId).document(withId).updateData(values)
                    }
                }
            }
        }
    }
