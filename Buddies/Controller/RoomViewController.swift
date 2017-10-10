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

class RoomViewController: BaseViewController,UITableViewDelegate,UITableViewDataSource,UIScrollViewDelegate {
    
    // MARK: UI variables
    private var messageTableView: UITableView?
    private var roomModel: RoomModel?
    private var localGroupModel: GroupModel?
    private var roomMemberTableView: UITableView?
    private var maskView: UIView?
    private var roomMeberList: [Membership] = []
    private var messageList: [MessageModel] = []
    private let messageTableViewHeight = (Constants.Size.screenHeight-64-40)
    private var tableTap: UIGestureRecognizer?
    private var topIndicator: UIActivityIndicatorView?
    private var navigationTitleLabel: UILabel?
    private var buddiesInputView : BuddiesInputView?

    // MARK: - Life Circle
    init(room: RoomModel){
        super.init()
        self.roomModel = room
        self.localGroupModel = User.CurrentUser[(self.roomModel?.localGroupId)!]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpTopNavigationView()
        self.setUpSupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(messageNotiReceived(noti:)), name: NSNotification.Name(rawValue: MessageReceptionNotificaton), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func messageNotiReceived(noti: Notification){
        let paramDict = noti.object as! Dictionary<String, String>
        let fromEmail = paramDict["from"]
        if let localGroup = User.CurrentUser.getSingleGroupWithContactEmail(email: fromEmail!){
            if(localGroup.groupId == self.localGroupModel?.groupId){
                localGroup.unReadedCount = 0
                if(self.roomModel?.roomId != nil){
                    self.requestRecivedMessages()
                }
            }
        }
    }
    
    // MARK: - SparkSDK: lising message/ligsting member in a room
    func requestMessageList(){
        if(self.roomModel?.roomId == nil || self.roomModel?.roomId.length == 0){
            self.updateNavigationTitle()
            return
        }
        self.topIndicator?.startAnimating()
        SparkSDK?.messages.list(roomId: (self.roomModel?.roomId)!, max: 30, queue: nil, completionHandler: { (response: ServiceResponse<[Message]>) in
            self.topIndicator?.stopAnimating()
            switch response.result {
            case .success(let value):
                print(value)
                self.messageList.removeAll()
                for message in value{
                    let msgModel = MessageModel(message: message)
                    msgModel?.messageState = MessageState.received
                    msgModel?.localGroupId = self.roomModel?.localGroupId
                    if(msgModel?.text == nil){
                        msgModel?.text = ""
                    }
                    self.messageList.insert(msgModel!, at: 0)
                }
                self.updateNavigationTitle()
                self.messageTableView?.reloadData()
                if(self.messageList.count > 0){
                    let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
                    self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
                }
                break
            case .failure:
                self.updateNavigationTitle()
                break
            }
        })
    }
    
    func requestRecivedMessages(){
        self.topIndicator?.startAnimating()
        self.navigationTitleLabel?.text = ""
        SparkSDK?.messages.list(roomId: (self.roomModel?.roomId)!, max: 1, queue: nil, completionHandler: { (response: ServiceResponse<[Message]>) in
            self.topIndicator?.stopAnimating()
            switch response.result {
            case .success(let value):
                print(value)
                for message in value{
                    let msgModel = MessageModel(message: message)
                    msgModel?.messageState = MessageState.received
                    msgModel?.localGroupId = self.roomModel?.localGroupId
                    if(msgModel?.text == nil){
                        msgModel?.text = ""
                    }
                    self.messageList.append(msgModel!)
                }
                self.messageTableView?.reloadData()
                if(self.messageList.count > 0){
                    let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
                    self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
                }
                self.updateNavigationTitle()
                break
            case .failure:
                self.updateNavigationTitle()
                break
            }
        })
    }
    
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
    func sendMessage(text: String){
        if(text.length == 0){
            return
        }
        let tempMessageModel = MessageModel()
        tempMessageModel.roomId = self.roomModel?.roomId
        tempMessageModel.messageState = MessageState.willSend
        tempMessageModel.personId = User.CurrentUser.id
        tempMessageModel.personEmail = EmailAddress.fromString(User.CurrentUser.email)
        tempMessageModel.text = text
        tempMessageModel.localGroupId = self.roomModel?.localGroupId
        
        if(self.localGroupModel?.groupType == .singleMember){
            tempMessageModel.toPersonEmail = EmailAddress.fromString((self.localGroupModel?[0]?.email)!)
        }
        
        self.messageList.append(tempMessageModel)
        self.messageTableView?.insertRows(at: [IndexPath(row: self.messageList.count-1, section: 0)], with: .bottom)
        self.buddiesInputView?.inputTextView?.text = ""
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
        return
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
      
        self.requestMessageList()
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
        self.buddiesInputView = BuddiesInputView(frame: CGRect(x: 0, y: messageTableViewHeight, width: bottomViewWidth, height: 40) , tableView: self.messageTableView!)
        self.buddiesInputView?.sendBtnClickBlock = { (textStr: String) in
           self.sendMessage(text: textStr)
        }
        self.view.addSubview(self.buddiesInputView!)
    }
    
    private func setUpMembertableView(){
        if(self.roomMemberTableView == nil){
            self.roomMemberTableView = UITableView(frame: CGRect(Constants.Size.screenWidth,0,Constants.Size.screenWidth/4*3,Constants.Size.screenHeight))
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
            if(self.messageList[indexPath.row].files != nil){
                fileCount = (self.messageList[indexPath.row].files?.count)!
            }
            let cellHeight = MessageTableCell.getCellHeight(text: self.messageList[indexPath.row].text!, imageCount: fileCount)
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
            let messageModel = self.messageList[index]
            var reuseCell = tableView.dequeueReusableCell(withIdentifier: "MessageTableCell")
            if reuseCell != nil{

            }else{
                reuseCell = MessageTableCell(messageModel: messageModel)
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
