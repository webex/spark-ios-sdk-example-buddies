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
import ObjectMapper
import Cartography
import Photos
class RoomViewController: BaseViewController,UITableViewDelegate,UITableViewDataSource,UIScrollViewDelegate {
    
    // MARK: UI variables
    private var messageTableView: UITableView?
    public var roomModel: RoomModel?
    private var roomMemberTableView: UITableView?
    private var maskView: UIView?
    private var roomMeberList: [Membership] = []
    private var messageList: [Message] = []
    private let messageTableViewHeight = Constants.Size.navHeight > 64 ? (Constants.Size.screenHeight-Constants.Size.navHeight-74) : (Constants.Size.screenHeight-Constants.Size.navHeight-40)
    private var tableTap: UIGestureRecognizer?
    private var topIndicator: UIActivityIndicatorView?
    private var navigationTitleLabel: UILabel?
    private var buddiesInputView : BuddiesInputView?
    private var callVC : BuddiesCallViewController?

    // MARK: - Life Circle
    init(room: RoomModel){
        super.init()
        self.roomModel = room
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpTopNavigationView()
        self.setUpSupViews()
        self.requestMessageData()

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let buddiesInputView = self.buddiesInputView{
            buddiesInputView.selectedAssetCollectionView?.removeFromSuperview()
        }
    }
    
    func requestMessageData(){
        if User.CurrentUser.phoneRegisterd{
            self.requestMessageList()
        }else{
            SparkSDK?.phone.register({ (error) in
                if error == nil{
                    self.requestMessageList()
                }
            })
        }
    }
    // MARK: - SparkSDK: listing member in a room
    func requestMessageList(){
        if let roomId = self.roomModel?.roomId{
            self.topIndicator?.startAnimating()
            SparkSDK?.messages?.list(roomId: roomId,completionHandler: { (response: ServiceResponse<[MessageModel]>) in
                self.topIndicator?.stopAnimating()
                self.updateNavigationTitle()
                switch response.result {
                case .success(let value):
                    self.messageList.removeAll()
                    for messageModel in value{
                        let tempMessage = Message(messageModel: messageModel)
                        tempMessage?.localGroupId = self.roomModel?.localGroupId
                        tempMessage?.messageState = MessageState.received
                        self.messageList.insert(tempMessage!, at: 0)
                    }
                    self.messageTableView?.reloadData()
                    let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
                    self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
                    break
                case .failure:
                    break
                }
            })
        }
    }
    
    // MARK: - SparkSDK: listing member in a room
    func requestRoomMemberList(){
        KTActivityIndicator.singleton.show(title: "Loading")
        SparkSDK?.memberships.list(roomId: (self.roomModel?.roomId)!) { (response: ServiceResponse<[Membership]>) in
            KTActivityIndicator.singleton.hide()
            switch response.result {
            case .success(let value):
                self.roomMeberList.removeAll()
                for memberShip in value{
                    self.roomMeberList.append(memberShip)
                }
                self.roomMemberTableView?.reloadData()
                break
            case .failure:
                break
            }
        }
    }
    
    // MARK: - SparkSDK: post message | make call to a room
    func sendMessage(text: String, _ assetList:[BDAssetModel]? = nil , _ mentionList:[Contact]? = nil){
        let tempMessageModel = Message()
        tempMessageModel.roomId = self.roomModel?.roomId
        tempMessageModel.messageState = MessageState.willSend
        tempMessageModel.text = text
        if self.roomModel?.type == RoomType.direct{
            if let personEmail = self.roomModel?.roomMembers![0].email,
                let personId = self.roomModel?.roomMembers![0].id{
                tempMessageModel.toPersonEmail = EmailAddress.fromString(personEmail)
                tempMessageModel.toPersonId = personId
            }
        }
        tempMessageModel.personId = User.CurrentUser.id
        tempMessageModel.personEmail = EmailAddress.fromString(User.CurrentUser.email)
        tempMessageModel.localGroupId = self.roomModel?.localGroupId
        if let mentions = mentionList, mentions.count>0{
            var mentionModels : [MessageMentionModel] = []
            for mention in mentions{
                if mention.name == "ALL"{
                    mentionModels.append(MessageMentionModel.createGroupMentionItem())
                }else{
                    mentionModels.append(MessageMentionModel.createPeopleMentionItem(personId: mention.id))
                }
            }
            tempMessageModel.mentionList = mentionModels
        }
        if let models = assetList, models.count>0{
            var files : [FileObjectModel] = []
            tempMessageModel.fileNames = []
            let manager = PHImageManager.default()
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            for index in 0..<models.count{
                let asset = models[index].asset
                manager.requestImage(for: asset, targetSize: CGSize(width: 320, height: 320), contentMode: .aspectFill, options: nil) { (result, info) in
                    let date : Date = Date()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMMddyyyy:hhmmSSS"
                    let todaysDate = dateFormatter.string(from: date)
                    let name = "Image-" + todaysDate + ".png"
                    let destinationPath = documentsPath + "/" + name
                    if let data = UIImageJPEGRepresentation(result!, 1.0){
                        do{
                            try data.write(to: URL(fileURLWithPath: destinationPath))
                            let tempFile = FileObjectModel(name:name, localFileUrl: destinationPath)
                            let thumbFile = ThumbNailImageModel(localFileUrl: destinationPath,width: Int((result?.size.width)!), height : Int((result?.size.height)!))
                            tempFile.image = thumbFile
                            tempFile.fileType = FileType.Image
                            files.append(tempFile)
                            tempMessageModel.fileNames?.append(name)
                            if index == models.count - 1{
                                tempMessageModel.files = files
                                self.postMessage(message: tempMessageModel)
                            }
                        }catch let error as NSError{
                            print("Write File Error:" + error.description)
                        }
                    }
                }
            }
        }else{
            self.postMessage(message: tempMessageModel)
        }
        return
    }
    func postMessage(message: Message){
        self.messageList.append(message)
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.messageTableView?.reloadData()
        self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
        self.buddiesInputView?.inputTextView?.text = ""
    }
    
    func makeCall(isVideo: Bool){
        if let roomModel = self.roomModel{
            self.callVC = BuddiesCallViewController(room: roomModel)
            self.present(self.callVC!, animated: true) {
                self.callVC?.beginCall(isVideo: isVideo)
            }
        }
    }
    
    // MARK: - SparkSDK: receive a new message
    public func receiveNewMessage(message: MessageModel){
        if let _ = self.messageList.filter({$0.messageId == message.id}).first{
            return
        }
        let msgModel = Message(messageModel: message)
        msgModel?.messageState = MessageState.received
        msgModel?.localGroupId = self.roomModel?.localGroupId
        if(msgModel?.text == nil){
            msgModel?.text = ""
        }
        self.messageList.append(msgModel!)
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.messageTableView?.reloadData()
        self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
        if let callVc = self.callVC{
            callVc.receiveNewMessage(message: message)
        }
    }
    
    // MARK: - UI Implementation
    private func setUpTopNavigationView(){
        if(self.navigationTitleLabel == nil){
            self.navigationTitleLabel = UILabel(frame: CGRect(0,0,Constants.Size.screenWidth-80,20))
            self.navigationTitleLabel?.font = Constants.Font.NavigationBar.Title
            self.navigationTitleLabel?.textColor = UIColor.white
            self.navigationTitleLabel?.textAlignment = .center
            self.navigationItem.titleView = self.navigationTitleLabel
            self.topIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
            self.topIndicator?.hidesWhenStopped = true
            self.navigationTitleLabel?.addSubview(self.topIndicator!)
            self.topIndicator?.center = CGPoint((self.navigationTitleLabel?.center.x)!-20, 15)
        }
    }
    
    private func setUpSupViews(){
        self.updateBarItem()
        self.setUpMessageTableView()
        self.setUpBottomView()
    }
    
    private func updateBarItem() {
        var avator: UIImageView?
        if (User.CurrentUser.loginType != .None) {
            avator = User.CurrentUser.avator
            if let avator = avator {
                avator.setCorner(Int(avator.frame.height / 2))
            }
            let membersBtnItem = UIBarButtonItem(image: UIImage(named: "icon_members"), style: .plain, target: self, action: #selector(membersBtnClicked))
            self.navigationItem.rightBarButtonItem = membersBtnItem
        }
    }
    private func setUpMessageTableView(){
        if(self.messageTableView == nil){
            self.messageTableView = UITableView(frame: CGRect(0,0,Int(Constants.Size.screenWidth),Int(messageTableViewHeight)))
            self.messageTableView?.separatorStyle = .none
            self.messageTableView?.backgroundColor = Constants.Color.Theme.Background
            self.messageTableView?.delegate = self
            self.messageTableView?.dataSource = self
            self.messageTableView?.alwaysBounceVertical=true
            self.view.addSubview(self.messageTableView!)
        }
    }
    
    private func setUpBottomView(){
        let bottomViewWidth = Constants.Size.screenWidth
        if let group = User.CurrentUser[(self.roomModel?.localGroupId)!]{
            self.buddiesInputView = BuddiesInputView(frame: CGRect(x: 0, y: messageTableViewHeight, width: bottomViewWidth, height: 40) , tableView: self.messageTableView!, contacts: group.groupMembers)
            self.buddiesInputView?.sendBtnClickBlock = { (textStr: String, assetList:[BDAssetModel]?, mentionList:[Contact]?) in
                self.sendMessage(text: textStr, assetList, mentionList)
            }
            self.buddiesInputView?.videoCallBtnClickedBlock = {
                self.makeCall(isVideo: true)
            }
            self.buddiesInputView?.audioCallBtnClickedBlock = {
                self.makeCall(isVideo: false)
            }
            
            self.view.addSubview(self.buddiesInputView!)
        }else{
            self.buddiesInputView = BuddiesInputView(frame: CGRect(x: 0, y: messageTableViewHeight, width: bottomViewWidth, height: 40) , tableView: self.messageTableView!)
            self.buddiesInputView?.sendBtnClickBlock = { (textStr: String, assetList:[BDAssetModel]?, mentionList:[Contact]?) in
                self.sendMessage(text: textStr, assetList, mentionList)
            }
            self.view.addSubview(self.buddiesInputView!)
        }

    }
    
    private func setUpMembertableView(){
        if(self.roomMemberTableView == nil){
            let offSetY : CGFloat = Constants.Size.screenWidth > 375 ? 20.0 : 64.0
            self.roomMemberTableView = UITableView(frame: CGRect(Constants.Size.screenWidth,-offSetY,Constants.Size.screenWidth/4*3,Constants.Size.screenHeight+offSetY))
            self.roomMemberTableView?.separatorStyle = .none
            self.roomMemberTableView?.backgroundColor = Constants.Color.Theme.Background
            self.roomMemberTableView?.delegate = self
            self.roomMemberTableView?.dataSource = self
        }
    }
    
    private func setUpMaskView(){
        if(self.maskView == nil){
            self.maskView = UIView(frame: CGRect.zero)
            self.maskView?.frame = CGRect(x: 0, y: 0, width: Constants.Size.screenWidth, height: Constants.Size.screenHeight)
            self.maskView?.backgroundColor = UIColor.black
            self.maskView?.alpha = 0
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissMemberTableView))
            self.maskView?.addGestureRecognizer(tap)
        }
    }
    
    @objc private func membersBtnClicked(){
        self.buddiesInputView?.inputTextView?.resignFirstResponder()
        self.slideMembersTableView()
    }
    
    @objc public func slideMembersTableView() {
        self.setUpMaskView()
        self.setUpMembertableView()
        self.navigationController?.view.addSubview(self.maskView!)
        self.navigationController?.view.addSubview(self.roomMemberTableView!)
        
        UIView.animate(withDuration: 0.2, animations: { 
            self.roomMemberTableView?.transform = CGAffineTransform(translationX: -Constants.Size.screenWidth/4*3, y: 0)
            self.maskView?.alpha = 0.4
        }) { (_) in
            self.requestRoomMemberList()
        }
        
    }
    @objc public func dismissMemberTableView(){
        UIView.animate(withDuration: 0.2, animations: {
            self.roomMemberTableView?.transform = CGAffineTransform(translationX:0, y: 0)
            self.maskView?.alpha = 0
        }) { (complete) in
            self.maskView?.removeFromSuperview()
            self.roomMemberTableView?.removeFromSuperview()
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if(tableView == self.roomMemberTableView){
            return CGFloat(membershipTableCellHeight)
        }else{
            var fileCount = 0
            var imageCount = 0
            if(self.messageList[indexPath.row].files != nil){
                imageCount = (self.messageList[indexPath.row].files?.filter({$0.fileType == FileType.Image}).count)!
                fileCount = (self.messageList[indexPath.row].files?.filter({$0.fileType != FileType.Image}).count)!
            }
            let cellHeight = MessageTableCell.getCellHeight(text: self.messageList[indexPath.row].text!, imageCount: imageCount, fileCount: fileCount)
            return cellHeight
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(tableView == self.roomMemberTableView){
            return self.roomMeberList.count
        }else{
            return self.messageList.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if(tableView == self.roomMemberTableView){
            let index = indexPath.row
            let memberModel = self.roomMeberList[index]
            var reuseCell = tableView.dequeueReusableCell(withIdentifier: "PeopleListTableCell")
            if reuseCell != nil{
                (reuseCell as! PeopleListTableCell).updateMembershipCell(newMemberShipModel: memberModel)
            }else{
                reuseCell = PeopleListTableCell(membershipModel: memberModel)
            }
            return reuseCell!
        }else{
            let index = indexPath.row
            let message = self.messageList[index]
            var reuseCell = tableView.dequeueReusableCell(withIdentifier: "MessageTabelCell")
            if reuseCell == nil{
                reuseCell = MessageTableCell(message: message)
            }
            return reuseCell!
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if(tableView == self.roomMemberTableView){
            return 64
        }else{
            return 0
        }
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if(tableView == self.roomMemberTableView){
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: Constants.Size.screenWidth/4*3, height: 64))
            headerView.backgroundColor = Constants.Color.Theme.Main
            let label = UILabel(frame: CGRect(x: 0, y: 20, width: headerView.frame.size.width, height: headerView.frame.size.height-20))
            label.text = "Members"
            label.textColor = UIColor.white
            label.textAlignment = .center
            label.font = Constants.Font.NavigationBar.Title
            headerView.addSubview(label)
            return headerView
        }else{
            return nil
        }

    }

    // MARK: Other Functions
    private func updateNavigationTitle(){
        self.navigationTitleLabel?.text = self.roomModel?.title != nil ? self.roomModel?.title! : "No Name"
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
