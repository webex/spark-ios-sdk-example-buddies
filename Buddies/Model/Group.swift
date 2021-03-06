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

/*
  -note: Buddies use group as unit of contact
  -note: even single contact will be a single member group
 */
enum GroupType : Int{
    case none = 0
    case singleMember
    case multiMember
}

class Group: NSObject,NSCoding {
    
    // gourpId represents local groupid, generated by members' email md5 string
    var groupId: String?
    // groupName represents local group name, by defaults generated by members' email
    var groupName: String?
    var groupMembers: [Contact] = []
    var groupType: GroupType
    var grouMemberCount: Int {
        get{
            return groupMembers.count
        }
    }
    var unReadedCount: Int = 0
    
    override init(){
        self.groupType = .none
        self.unReadedCount = 0
        super.init()
    }
    init(contact: Contact) {
        self.groupType = .singleMember
        super.init()
        self.groupMembers.append(contact)
        self.groupId = self.updateGroupId()
        self.groupName = self.updateGroupName()
        self.unReadedCount = 0
    }
    
    init(contacts: [Contact],name: String?){
        self.groupType = .multiMember
        super.init()
        self.groupMembers = contacts
        if let nameStr = name{
            if(nameStr.length > 0){
                self.groupName = nameStr
            }else{
                self.groupName = self.updateGroupName()
            }
        }else{
            self.groupName = self.updateGroupName()
        }
        self.groupId = self.updateGroupId()
        self.unReadedCount = 0
    }
    
    convenience init(contactList: [Contact], name: String?){
        if(contactList.count == 0){
            self.init()
        }else if(contactList.count == 1){
            self.init(contact: contactList[0])
        }else{
            self.init(contacts: contactList, name: name)
        }
    }
    
    // MARK: Subscrib index
    subscript(index: Int) -> Contact? {
        return self.groupMembers.safeObjectAtIndex(index)
    }
    
    public func getMemberWithEmail(email: String)->Contact{
        return self.groupMembers.filter({$0.email ~= email}).first!
    }
    
    

    public func addMemberToGroup(_ newContact: Contact){
        self.groupMembers.append(newContact)
        self.groupId = self.updateGroupId()
        self.updateGroupType()
    }
    
    public func removeMemberWithEmail(_ email: String){
       _  = self.groupMembers.removeObject(equality: {$0.email ~= email})
        self.groupId = self.updateGroupId()
        self.updateGroupType()
    }
    public func clearContactSelection(){
        for contact in self.groupMembers{
            contact.isChoosed = false
        }
    }
    
    // MARK: private Methods
    private func updateGroupId()->String{
        if(self.groupMembers.count == 1){
            return self.groupMembers[0].email
        }
        var gourpIdStr = ""
        self.groupMembers.sort { (contact1, contact2) -> Bool in
            return contact1.email < contact2.email
        }
        for contact in self.groupMembers{
            gourpIdStr += contact.email + "+"
        }
        return gourpIdStr.md5
    }
    
    private func updateGroupName()->String{
        if(self.groupMembers.count == 1){
            return self.groupMembers[0].name
        }
        var gourpNameStr = ""
        self.groupMembers.sort { (contact1, contact2) -> Bool in
            return contact1.name < contact2.name
        }
        for index in 0..<self.groupMembers.count{
            let contact = self[index]
            if(index != self.groupMembers.count-1){
                gourpNameStr += (contact?.name)! + " , "
            }else{
                gourpNameStr += (contact?.name)!
            }

        }
        return gourpNameStr
    }
    
    private func updateGroupType(){
        if(self.groupMembers.count == 0){
            self.groupType = .none
        }else if(self.groupMembers.count == 1){
            self.groupType = .singleMember
        }else{
            self.groupType = .multiMember
        }
    }
    public class func getGroupRoomId(contacts: [Contact])->String{
        if(contacts.count == 1){
            return contacts[0].email.md5
        }
        var gourpIdStr = ""
        for contact in contacts{
            gourpIdStr += contact.email + "+"
        }
        return gourpIdStr.md5
    }
    
    public class func getGroupRoomName(contacts: [Contact])->String{
        if(contacts.count == 1){
            return contacts[0].name
        }
        var gourpNameStr = ""
        for index in 0..<contacts.count{
            let contact = contacts[index]
            if(index != contacts.count-1){
                gourpNameStr += (contact.name) + " , "
            }else{
                gourpNameStr += (contact.name)
            }
            
        }
        return gourpNameStr
    }
    
    
    // MARK: NSCoding Implementation
    public func encode(with aCoder: NSCoder){
        if self.groupId != nil{
            aCoder.encode(self.groupId, forKey: "groupId")
        }
        if self.groupName != nil{
            aCoder.encode(self.groupName, forKey: "groupName")
        }
        aCoder.encode(self.groupMembers, forKey: "groupMembers")
        aCoder.encode(self.groupType.rawValue, forKey: "groupType")
        aCoder.encode(self.unReadedCount , forKey:"unreadedCount")
    }
    
    public required init?(coder aDecoder: NSCoder){
        self.groupName = aDecoder.decodeObject(forKey: "groupName") as? String
        self.groupId = aDecoder.decodeObject(forKey: "groupId") as? String
        self.groupMembers = (aDecoder.decodeObject(forKey: "groupMembers") as? [Contact])!
        self.groupType = (GroupType(rawValue: Int(aDecoder.decodeCInt(forKey: "groupType"))))!
        self.unReadedCount = Int(aDecoder.decodeCInt(forKey: "unreadedCount"))
    }
    
}
