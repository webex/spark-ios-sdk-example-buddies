// Copyright 2016-2017 Cisco Systems Inc
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import SparkSDK


/*
 -note: Buddies use MessageModel to wrap message model from remote server
 */
enum MessageState : Int{
    case idle
    case received
    case willSend
    case sendFailed
}

class MessageModel: NSObject {

    public var messageId: String?
    
    public var personId: String?
    
    public var personEmail: EmailAddress?
    
    public var roomId: String?
    
    public var text: String?
    
    public var files: [String]?
    
    public var toPersonId: String?
    
    public var toPersonEmail: EmailAddress?
    
    public var created: Date?
    
    public var messageState: MessageState?
    
    public var localGroupId: String? //GroupId contain witch Room it is involved in
    
    public var imageDataDict: Dictionary<String, Data>?
    
    convenience init?(message: Message) {
        self.init()
        if let roomId = message.roomId{
            self.roomId = roomId
        }
        if let messageId = message.id{
            self.messageId = messageId
        }
        if let personId = message.personId{
            self.personId = personId
        }
        if let personEmail = message.personEmail{
            self.personEmail = personEmail
        }
        if let text = message.text{
            self.text = text
        }
        if let messageId = message.id{
            self.messageId = messageId
        }
        if let files = message.files{
            self.files = files
        }
        if let toPersonId = message.toPersonId{
            self.toPersonId = toPersonId
        }
        if let toPersonEmail = message.toPersonEmail{
            self.toPersonEmail = toPersonEmail
        }
        if let created = message.created{
            self.created = created
        }
    }
    
}
