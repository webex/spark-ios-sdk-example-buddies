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
import CallKit
import Cartography
import SparkSDK

class BuddiesCallViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,UIScrollViewDelegate{
    
    // MARK: - UI variables
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private var vibrancyView: UIVisualEffectView?
    private var statusLable: UILabel?
    private var hangupBtn: UIButton?
    private var muteVideoBtn: UIButton?
    private var muteVoiceBtn: UIButton?
    private var switchCameraBtn: UIButton?
    private var screenShareBtn: UIButton?
    private var messageBtn: UIButton?
    private let callee: Contact
    let callkit: CXProvider?
    let uuid: UUID?
    weak var currentCall: Call?
    private var timer: Timer?
    private var startTime: Date?
    private var isGroupCall: Bool = false
    private var memberShipList: [CallMembership]?
    private var memberShipViewList: [CallMemberShipView]? = []
    
    
    /// removeVideoView receives and presents remote camera
    private(set) var remoteVideoView: MediaRenderView?
    /// localVideoView present local camera video
    private(set) var localVideoView: MediaRenderView?
    /// screenShareView present screenShare render view
    private(set) var screenShareView: MediaRenderView?
    
    
    
    // MARK: Message Feature UI
    private static var callContext = 0
    private let messageTableViewHeight = (Constants.Size.screenHeight/4)
    private var backScrollView: UIScrollView?
    private var memberShipScrollView: UIScrollView?
    private var messageTableView: UITableView?
    private var messageList: [MessageModel] = []
    private var bottomBackView: UIView?
    private var buddiesInputView : BuddiesInputView?
    private var isReceivingScreenShare: Bool = false
    
    // MARK: - Life Circle
    init(callee: Contact, uuid: UUID? = nil, callkit: CXProvider? = nil) {
        self.isGroupCall = false
        self.callee = callee
        self.uuid = uuid
        self.callkit = callkit
        super.init(nibName: nil, bundle: nil);
    }
    
    init(room: RoomModel, uuid: UUID? = nil, callkit: CXProvider? = nil){
        self.isGroupCall = true
        self.callee = Contact(id: "", name: room.title!, email: room.roomId)
        self.uuid = uuid
        self.callkit = callkit
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        self.setNeedsStatusBarAppearanceUpdate();
        self.view.backgroundColor = UIColor.MKColor.BlueGrey.P700
        self.setUpSubViews()
    }
    
    // MARK: - SparkSDK: beginVideoCall
    func beginVideoCall(){
        KTActivityIndicator.singleton.show(title: "Connecting..")
        /* check if user's phone is registerd with Cisco could */
        if(User.CurrentUser.phoneRegisterd){
            self.dialCall()
        }else{
            SparkSDK?.phone.register({ (_ error) in
                if(error == nil){
                    User.CurrentUser.phoneRegisterd = true
                    self.dialCall()
                }else{
                    KTActivityIndicator.singleton.hide()
                    self.disMissVC(error)
                }
            })
        }
    }
    
    private func dialCall(){
        SparkSDK?.phone.dial(self.callee.email, option:  MediaOption.audioVideoScreenShare(video: (self.localVideoView!, self.remoteVideoView!), screenShare: self.screenShareView!)) { result in
            KTActivityIndicator.singleton.hide()
            switch result {
            case .success(let call):
                self.callStateChangeCallBacks(call: call)
            case .failure(let error):
                self.disMissVC(error)
            }
        }
    }
    
    
    // MARK: - SparkSDK: asnwerNewIncoming call /
    func answerNewIncomingCall(call: Call, callKitAction: CXAction){
        if(self.currentCall == nil){
            self.answerCall(call,callKitAction)
        }
        else{
            if(self.currentCall?.status == .connected){
                self.currentCall?.hangup(completionHandler: { ( _ error) in
                    if let uuid = self.currentCall?.uuid, let callkit = self.callkit {
                        callkit.reportCall(with: uuid, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
                    }
                    self.resetViews()
                    self.answerCall(call,callKitAction)
                })
            }else{
                self.currentCall?.reject(completionHandler: { ( _ error) in
                    if let uuid = self.currentCall?.uuid, let callkit = self.callkit {
                        callkit.reportCall(with: uuid, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
                    }
                    self.resetViews()
                    self.answerCall(call,callKitAction)
                })
            }
        }
    }
    
    
    private func answerCall(_ call: Call, _ answerAction: CXAction){
        KTActivityIndicator.singleton.hide()
        self.timer?.invalidate()
        self.timer = nil
        self.startTime = nil
        call.answer(option:   MediaOption.audioVideoScreenShare(video: (local :self.localVideoView!,remote : self.remoteVideoView!), screenShare: self.screenShareView)) { error in
            if let error = error{
                self.disMissVC(error)
            }else{
                self.callStateChangeCallBacks(call: call)
                answerAction.fulfill()
            }
        }
    }
    
    private func resetViews(){
        self.remoteVideoView?.removeFromSuperview()
        self.localVideoView?.removeFromSuperview()
        self.statusLable?.removeFromSuperview()
        self.memberShipScrollView?.removeFromSuperview()
        self.backScrollView?.removeFromSuperview()
        self.setUpSubViews()
    }
    
    // MARK: - SparkSDK: call state change processing code here...
    private func callStateChangeCallBacks(call: Call) {
        self.currentCall = call
        self.memberShipList = call.memberships
        /* Callback when remote participant(s) answered and this *call* is connected. */
        call.onConnected = { [weak self] in
            print("Call ======= > Connected")
            KTActivityIndicator.singleton.hide()
            self?.setUpMemberShipView()
            self?.updateUIForCallStatusChanged()
        }
        
        /* Callback when this *call* is disconnected (hangup, cancelled, get declined or other self device pickup the call). */
        call.onDisconnected = { [weak self] reason in
            print("Call ======= > DisConnected")
            var reasonStr = "Disconnecting"
            switch reason {
            case .remoteLeft:
                reasonStr = "Remote HangUp"
                break;
            case .remoteDecline:
                reasonStr = "Declined Call"
                break
            case .localDecline:
                reasonStr = "Declining"
                break
            case .localLeft:
                reasonStr = "Hanging Up"
                return
            case .localCancel:
                reasonStr = "Canceling"
                break
            default:
                break
            }
            self?.endCall(call, reasonStr)
        }
        /* Callback when the media types of this *call* have changed. */
        call.onMediaChanged = {[weak self] mediaChangeType in
            switch mediaChangeType {
                /* Local/Remote video rendering view size has changed */
            case .localVideoViewSize,.remoteVideoViewSize:
                break
                /* This might be triggered when the remote party muted or unmuted the audio. */
            case .remoteSendingAudio:
                break
                /* This might be triggered when the remote party muted or unmuted the video. */
            case .remoteSendingVideo:
                break
                /* This might be triggered when the local party muted or unmuted the video. */
            case .sendingAudio:
                break
                /* This might be triggered when the local party muted or unmuted the aideo. */
            case .sendingVideo:
                break
                /* Camera FacingMode on local device has switched. */
            case .cameraSwitched:
                break
                /* Whether loud speaker on local device is on or not has switched. */
            case .spearkerSwitched:
                break
            case .receivingAudio:
                break
            case .receivingAudio:
                break
            case .receivingScreenShare:
                break
            case .remoteSendingScreenShare(let isSending):
                self?.updateUIforScreenShareing(isSending)
                break
            default:
                break
            }
        }
        
        /* Callback when remote participant(s) join/left/decline connected. */
        call.onCallMembershipChanged = { [weak self] memberShipChangeType  in
            if self != nil {
                switch memberShipChangeType {
                    /* This might be triggered when membership joined the call */
                case .joined(let memberShip):
                    
                    print("memberShip=======>\(memberShip.email!) joined")
                    self?.updateMemberShipView(membership: memberShip)
                    break
                    /* This might be triggered when membership left the call */
                case .left(let memberShip):
                    print("memberShip=======>\(memberShip.email!) left")
                    self?.updateMemberShipView(membership: memberShip)
                    break
                    /* This might be triggered when membership declined the call */
                case .declined(let memberShip):
                    print("memberShip========> \(memberShip.email!) declined")
                    self?.updateMemberShipView(membership: memberShip)
                    break
                default:
                    break
                }
            }
        }
    }
    
    func updateUIforScreenShareing(_ isReceiving: Bool){
        if(isReceiving){
            UIView.animate(withDuration: 0.15, animations: {
                self.screenShareBtn?.isHidden = false
            })
            self.screenShareView?.backgroundColor = UIColor.black
        }else{
            self.screenShareBtn?.isHidden = true
            self.screenShareView?.backgroundColor = UIColor.clear
        }
    }
    
    // MARK: - SparkSDK: hang up call
    func endCall(_ call: Call, _ endReason: String? = nil){
        let isCurrentCall = (call.uuid.uuidString == self.currentCall?.uuid.uuidString)
        if call.status == .connected {
            if(isCurrentCall){
                KTActivityIndicator.singleton.show(title: endReason! + "..")
            }
            call.hangup(completionHandler: { (_ error) in
                if(isCurrentCall){
                    if let uuid = self.currentCall?.uuid, let callkit = self.callkit {
                        callkit.reportCall(with: uuid, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
                    }
                    self.currentCall = nil
                    self.disMissVC(error, endReason)
                }
            })
        }else{
            call.reject(completionHandler: { (_ error) in
                if(isCurrentCall){
                    if let uuid = self.currentCall?.uuid, let callkit = self.callkit {
                        callkit.reportCall(with: uuid, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
                    }
                    self.disMissVC(error, endReason)
                }
            })
        }
    }
    
    
    // MARK: - UI Imeplementation
    private func setUpSubViews() {
        let blur = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurView = UIVisualEffectView(effect: blur)
        self.view.addSubview(blurView)
        constrain(blurView) { view in
            view.size == view.superview!.size;
            view.center == view.superview!.center;
        }
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blur))
        blurView.contentView.addSubview(self.vibrancyView!)
        constrain(self.vibrancyView!) { view in
            view.size == view.superview!.size;
            view.center == view.superview!.center;
        }
        
        self.remoteVideoView = MediaRenderView(frame: self.view.bounds)
        self.remoteVideoView?.backgroundColor = UIColor.clear
        self.view.addSubview(self.remoteVideoView!)
        constrain(self.remoteVideoView!) { view in
            view.size == view.superview!.size;
            view.center == view.superview!.center;
        }
        self.localVideoView = MediaRenderView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        self.localVideoView?.backgroundColor = UIColor.red
        self.localVideoView = MediaRenderView(frame: CGRect.zero)
        self.localVideoView?.backgroundColor = UIColor.clear
        self.view.addSubview(self.localVideoView!)
        constrain(self.localVideoView!) { view in
            view.right == view.superview!.right - 5
            view.top == view.superview!.top + 5
            view.width == view.superview!.width / 4
            view.height == view.superview!.height / 4
        }
        
        self.statusLable = UILabel()
        self.statusLable?.font = Constants.Font.StatusBar
        self.statusLable?.textAlignment = .left
        self.statusLable?.textColor = UIColor.white
        self.statusLable?.numberOfLines = 1;
        self.statusLable?.lineBreakMode = .byTruncatingTail;
        self.view.addSubview(self.statusLable!)
        constrain(self.statusLable!) { view in
            view.left == view.superview!.left + 20
            view.top == view.superview!.top + 30
            view.width == view.superview!.width / 2
            view.height == 30
        }
        
        self.memberShipScrollView = UIScrollView(frame: CGRect.zero)
        self.memberShipScrollView?.showsHorizontalScrollIndicator = false
        self.memberShipScrollView?.alwaysBounceHorizontal = true
        self.view.addSubview(memberShipScrollView!)
        constrain(self.memberShipScrollView!) { view in
            view.top == view.superview!.top + 64
            view.left == view.superview!.left
            view.width == view.superview!.width/4*3 - 10
            view.height == 50
        }
        
        self.backScrollView = UIScrollView(frame: CGRect.zero)
        self.backScrollView?.isPagingEnabled = true
        self.backScrollView?.showsHorizontalScrollIndicator = false
        self.backScrollView?.delegate = self
        self.backScrollView?.contentSize = CGSize(Constants.Size.screenWidth*3, Constants.Size.screenHeight-114)
        self.backScrollView?.contentOffset = CGPoint(Constants.Size.screenWidth, 0)
        self.backScrollView?.bounces = false
        self.backScrollView?.layer.masksToBounds = false
        self.view.addSubview(self.backScrollView!)
        constrain(self.backScrollView!) { view in
            view.top == view.superview!.top + 114
            view.width == view.superview!.width
            view.height == view.superview!.height - 114
        }
        
        self.screenShareView = MediaRenderView(frame: CGRect.zero)
        self.screenShareView?.backgroundColor = UIColor.clear
        self.backScrollView?.addSubview(self.screenShareView!)
        
        constrain(self.screenShareView!) { view in
            view.centerX == view.superview!.centerX
            view.top == view.superview!.top-114
            view.width == view.superview!.width
            view.height == view.superview!.height + 114
        }
        
        self.hangupBtn = self.createButton(type: .hangup)
        self.backScrollView?.addSubview(self.hangupBtn!)
        constrain(self.hangupBtn!,self.view!) { view, backView in
            view.centerX ==  view.superview!.centerX*3
            view.bottom == backView.bottom-28
            view.width == 48
            view.height == 48
        }
        self.muteVoiceBtn = self.createButton(type: .muteVoice)
        self.muteVideoBtn = self.createButton(type: .muteVideo)
        self.switchCameraBtn = self.createButton(type: .switchCamera)
        self.screenShareBtn = self.createButton(type: .screenShare)
        self.screenShareBtn?.frame = CGRect(x: Constants.Size.screenWidth + 20, y: Constants.Size.screenHeight - 114 - 128, width: 32, height: 32)
        self.screenShareBtn?.backgroundColor = UIColor.orange
        self.screenShareBtn?.layer.cornerRadius = 16.0
        self.messageBtn = self.createButton(type: .message)
        self.messageBtn?.frame = CGRect(x: Constants.Size.screenWidth*2 - 52, y: Constants.Size.screenHeight - 114 - 128, width: 32, height: 32)
        
        self.muteVideoBtn?.isEnabled = false
        self.muteVoiceBtn?.isEnabled = false
        self.muteVideoBtn?.tintColor = UIColor.white
        self.muteVoiceBtn?.tintColor = UIColor.white
        self.switchCameraBtn?.isEnabled = false
        self.screenShareBtn?.isHidden = true
        self.messageBtn?.isEnabled = false
        self.backScrollView?.addSubview(self.muteVoiceBtn!)
        self.backScrollView?.addSubview(self.muteVideoBtn!)
        self.backScrollView?.addSubview(self.switchCameraBtn!)
        self.backScrollView?.addSubview(self.screenShareBtn!)
        self.backScrollView?.addSubview(self.messageBtn!)
        constrain(self.muteVideoBtn!) { view in
            view.centerX == view.superview!.centerX*3
        }
        constrain(self.muteVoiceBtn!, self.muteVideoBtn!, self.switchCameraBtn!,self.view!) { view1, view2, view3, backView in
            distribute(by: 40, horizontally: view1, view2, view3)
            view1.width == 48
            view1.height == 48
            view2.width == 48
            view2.height == 48
            view3.width == 48
            view3.height == 48
            view1.bottom == backView.bottom - 20 - 48 - 20
            view2.bottom == backView.bottom - 20 - 48 - 20
            view3.bottom == backView.bottom - 20 - 48 - 20
        }
        
        self.setUpMessageTableView()
        self.setUpBottomView()
        self.backScrollView?.isScrollEnabled = false
        self.statusLable?.text = "Connecting \(self.callee.name) ..."
        
    }
    
    enum ButtonType: Int {
        case hangup
        case muteVideo
        case muteVoice
        case switchCamera
        case screenShare
        case message
    }
    
    private func createButton(type: ButtonType) -> UIButton {
        let button = UIButton(frame: CGRect(0, 0, 60, 60));
        button.backgroundColor = UIColor.clear
        button.tintColor = UIColor.white
        button.tag = type.rawValue
        var icon: String
        switch type {
        case .hangup:
            icon = "hangup"
        case .muteVideo:
            icon = "mute_video"
        case .muteVoice:
            icon = "mute_voice"
        case .switchCamera:
            icon = "switch_camera"
        case .screenShare:
            icon = "icon_screenLeft"
        case .message:
            icon = "icon_messageRight"
        }
        button.setImage(UIImage(named: icon), for: .normal)
        button.addTarget(self, action: #selector(doButtonTap(sender:)), for: .touchUpInside)
        return button
    }
    
    @objc private func doButtonTap(sender: UIButton) {
        if let type = ButtonType(rawValue: sender.tag) {
            switch type {
            case .hangup:
                self.endCall(self.currentCall!, "Hang Up")
            case .muteVideo:
                if let call = self.currentCall {
                    call.sendingVideo = !call.sendingVideo
                    self.muteVideoBtn?.tintColor = call.sendingVideo ? UIColor.white : UIColor.gray
                }
            case .muteVoice:
                if let call = self.currentCall {
                    call.sendingAudio = !call.sendingAudio
                    self.muteVoiceBtn?.tintColor = call.sendingAudio ? UIColor.white : UIColor.gray
                }
            case .switchCamera:
                if let call = self.currentCall {
                    call.facingMode = (call.facingMode == Phone.FacingMode.environment) ? Phone.FacingMode.user : Phone.FacingMode.environment
                }
            case .screenShare:
                UIView.animate(withDuration: 0.25, animations: {
                    self.backScrollView?.contentOffset = CGPoint(x: 0, y: 0)
                })
                
            case .message:
                UIView.animate(withDuration: 0.25, animations: {
                    self.backScrollView?.contentOffset = CGPoint(x: Constants.Size.screenWidth*2, y: 0)
                })
            }
        }
    }
    
    private func updateUIForCallStatusChanged() {
        DispatchQueue.main.async {
            if self.currentCall?.status == .connected {
                self.muteVideoBtn?.isEnabled = true
                self.muteVoiceBtn?.isEnabled = true
                self.switchCameraBtn?.isEnabled = true
                self.messageBtn?.isEnabled = true
                self.backScrollView?.isScrollEnabled = true
                if #available(iOS 10.0, *) {
                    if self.startTime == nil {
                        self.startTime = Date()
                        self.statusLable?.text = String.stringFrom(timeInterval: self.startTime!.timeIntervalSinceNow)
                        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {_ in
                            if let date = self.startTime {
                                self.statusLable?.text = String.stringFrom(timeInterval: date.timeIntervalSinceNow)
                            }
                        }
                    }
                }else{
                    self.statusLable?.text = "Connected \(self.callee.name)"
                }
            }else if self.currentCall?.status == .disconnected{
                self.muteVideoBtn?.isEnabled = false
                self.muteVoiceBtn?.isEnabled = false
                self.switchCameraBtn?.isEnabled = false
                self.messageBtn?.isEnabled = false
            }
        }
    }
    
    private func setUpMessageTableView(){
        if(self.messageTableView == nil){
            self.messageTableView = UITableView(frame: CGRect(Int(Constants.Size.screenWidth*2),Int(messageTableViewHeight*3-154),Int(Constants.Size.screenWidth),Int(messageTableViewHeight)))
            self.messageTableView?.separatorStyle = .none
            self.messageTableView?.backgroundColor = UIColor.clear
            self.messageTableView?.delegate = self
            self.messageTableView?.dataSource = self
            self.backScrollView?.addSubview(self.messageTableView!)
        }
    }
    
    private func setUpBottomView(){
        let bottomViewWidth = Constants.Size.screenWidth*2
        self.buddiesInputView = BuddiesInputView(frame:  CGRect(x: bottomViewWidth, y: Constants.Size.screenHeight-154, width: bottomViewWidth, height: 40) , tableView: self.messageTableView!)
        self.buddiesInputView?.sendBtnClickBlock = { (textStr: String) in
            self.sendMessage(text: textStr)
        }
        self.backScrollView?.addSubview(self.buddiesInputView!)
    }
    
    // MARK: MemberShips View SetUp
    private func setUpMemberShipView(){
        if(self.isGroupCall && self.memberShipViewList?.count == 0){
            let sortedMemberList = self.memberShipList?.sorted(by: { (first: CallMembership, second: CallMembership) -> Bool in
                let r1 = (first.email! == User.CurrentUser.email) ? 1 : 0
                let r2 = (second.email! == User.CurrentUser.email) ? 1 : 0
                return (r1 > r2)
            })
            self.memberShipList = sortedMemberList
            if let listCount = self.memberShipList?.count{
                for index in 0..<listCount{
                    let tempMemberShipModel = self.memberShipList?[index]
                    let memberShipView = CallMemberShipView(frame: CGRect(x:20.0+(50.0*Double(index)),y: 2, width:46.0,height: 46.0), membership: tempMemberShipModel!)
                    self.memberShipViewList?.append(memberShipView)
                    self.memberShipScrollView?.addSubview(memberShipView)
                }
                self.memberShipScrollView?.contentSize = CGSize(width: (20.0+(50.0*Double(listCount))), height: 50)
            }
        }
    }
    
    private func updateMemberShipView(membership: CallMembership){
        if(self.isGroupCall){
            if let listCount = self.memberShipList?.count{
                for index in 0..<listCount{
                    let tempMemberShipModel = self.memberShipList?[index]
                    if tempMemberShipModel?.email == membership.email{
                        self.memberShipViewList?[index].updateMemberShipJoinState(newmemberShip: membership)
                    }
                }
            }
        }
    }
    
    // MARK: Page Logic Iplementation
    func sendMessage(text: String){
        if(text.length == 0){
            return
        }
        let tempMessageModel = MessageModel()
        
        if(self.isGroupCall){
            tempMessageModel.roomId = callee.email
        }else{
            tempMessageModel.roomId = User.CurrentUser.findLocalRoomWithId(localGroupId: callee.email.md5)?.roomId
        }
        tempMessageModel.messageState = MessageState.willSend
        tempMessageModel.personId = User.CurrentUser.id
        tempMessageModel.personEmail = EmailAddress.fromString( User.CurrentUser.email)
        tempMessageModel.text = text
        tempMessageModel.localGroupId = callee.email.md5
        tempMessageModel.toPersonEmail = EmailAddress.fromString(callee.email)
        
        self.messageList.append(tempMessageModel)
        self.messageTableView?.insertRows(at: [IndexPath(row: self.messageList.count-1, section: 0)], with: .bottom)
        self.buddiesInputView?.inputTextView?.text = ""
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.messageTableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
        return
    }
    
    private func disMissVC( _ error: Error? = nil, _ reasonString: String? = nil){
        if let reason = reasonString{
            KTActivityIndicator.singleton.show(title: reason + "..")
        }else{
            KTActivityIndicator.singleton.show(title: "Disconnecting..")
        }
        
        if(User.CurrentUser.phoneRegisterd){
            SparkSDK?.phone.deregister({ (error) in
                KTActivityIndicator.singleton.hide()
                User.CurrentUser.phoneRegisterd = false
                self.dismiss(animated: true) {}
                if let error = error {
                    KTInputBox.alert(error: error)
                }
            })
        }else{
            KTActivityIndicator.singleton.hide()
            self.dismiss(animated: true) {}
            if let error = error {
                KTInputBox.alert(error: error)
            }
        }
    }
    
    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        var fileCount = 0
        if(self.messageList[indexPath.row].files != nil){
            fileCount = (self.messageList[indexPath.row].files?.count)!
        }
        let cellHeight = MessageTableCell.getCellHeight(text: self.messageList[indexPath.row].text!, imageCount: fileCount)
        return cellHeight
        
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index = indexPath.row
        let messageModel = self.messageList[index]
        var reuseCell = tableView.dequeueReusableCell(withIdentifier: "MessageTableCell")
        if reuseCell != nil{
            //                (reuseCell as! PeopleListTableCell).updateMembershipCell(newMemberShipModel: memberModel)
        }else{
            reuseCell = MessageTableCell(messageModel: messageModel)
        }
        return reuseCell!
    }
    
    //MARK: UIScrollViewDelegate
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if scrollView == self.backScrollView {
            self.buddiesInputView?.inputTextView?.resignFirstResponder()
        }
    }
    
    // MARK: other functions
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

class CallMemberShipView: UIView{
    public enum JoinState: String {
        case Joined  = "joined"
        case Left = "left"
        case Declined = "declined"
        case Idle = "idle"
        case Unknown = "unknown"
    }
    var memberShip: CallMembership
    private var joinState: JoinState
    private var viewWidth: CGFloat = 0
    private var viewHeight: CGFloat = 0
    private var avatorImageView: UIImageView?
    private var maskLayer: CALayer?
    private var borderLayer: CAShapeLayer?
    
    init(frame: CGRect, membership: CallMembership){
        
        self.viewWidth = frame.size.width - 6
        self.viewHeight = frame.size.height - 6
        self.joinState = JoinState(rawValue: "unknown")!
        self.memberShip = membership
        super.init(frame: frame)
        self.setUpSubView()
        self.updateMemberShipJoinState(newmemberShip: self.memberShip)
    }
    
    private func setUpSubView(){
        
        /// -Setup AvatorView
        self.borderLayer = CAShapeLayer()
        let circlePath = UIBezierPath(roundedRect: CGRect(x:0,y:0,width:self.frame.size.width,height:self.frame.size.height), cornerRadius: self.frame.size.height/2)
        self.borderLayer?.fillColor = UIColor.lightGray.cgColor
        self.borderLayer?.path = circlePath.cgPath
        self.layer.addSublayer(self.borderLayer!)
        
        self.avatorImageView = UIImageView.init(frame: CGRect(x: 3, y: 3, width: viewWidth, height: viewHeight))
        self.avatorImageView?.layer.cornerRadius = self.viewHeight/2
        self.avatorImageView?.layer.masksToBounds = true
        self.avatorImageView?.backgroundColor = UIColor.darkGray
        self.avatorImageView?.image = UIImage.fontAwesomeIcon(name: .user, textColor: UIColor.white, size: CGSize(width: self.viewHeight, height: self.viewHeight))
        self.addSubview(self.avatorImageView!)
        DispatchQueue.global().async {
            SparkSDK?.people.list(email: EmailAddress.fromString(self.memberShip.email!) , max: 1) {
                (response: ServiceResponse<[Person]>) in
                switch response.result {
                case .success(let value):
                    for person in value{
                        if let tempContact = Contact(person: person){
                            if let url = tempContact.avatorUrl {
                                self.avatorImageView?.sd_setImage(with: URL(string: url), placeholderImage: tempContact.placeholder)
                            }
                            else {
                                self.avatorImageView?.image = tempContact.placeholder
                            }
                        }
                    }
                    break
                case .failure:
                    break
                }
            }
        }
        
        self.maskLayer = CALayer()
        self.maskLayer?.frame = CGRect(x: 3, y: 3, width: self.viewWidth, height: self.viewHeight)
        self.maskLayer?.backgroundColor = UIColor.black.cgColor
        self.maskLayer?.opacity = 0.5
        self.maskLayer?.cornerRadius = self.viewHeight/2
        self.layer.addSublayer(self.maskLayer!)
        
    }
    
    func updateMemberShipJoinState(newmemberShip: CallMembership){
        var stateStr = "unknown"
        switch (newmemberShip.state){
        case .declined:
            stateStr = "declined"
            break
        case .idle:
            stateStr = "idle"
            break
        case .joined:
            stateStr = "joined"
            break
        case .left:
            stateStr = "left"
            break
        default:
            break
        }
        self.joinState = JoinState(rawValue: stateStr)!
        self.updateMemberShipUI()
    }
    
    
    private func updateMemberShipUI(){
        switch self.joinState{
        case .Joined:
            self.maskLayer?.backgroundColor = UIColor.clear.cgColor
            self.borderLayer?.fillColor = Constants.Color.Theme.Main.cgColor
            break
        case .Left:
            self.maskLayer?.backgroundColor = UIColor.black.cgColor
            self.borderLayer?.fillColor = Constants.Color.Theme.Warning.cgColor
            break
        case .Declined:
            self.maskLayer?.backgroundColor = UIColor.black.cgColor
            self.borderLayer?.fillColor = Constants.Color.Theme.Warning.cgColor
            break
        case .Unknown:
            self.maskLayer?.backgroundColor = UIColor.black.cgColor
            self.borderLayer?.fillColor = UIColor.lightGray.cgColor
            break
        case .Idle:
            self.maskLayer?.backgroundColor = UIColor.black.cgColor
            self.borderLayer?.fillColor = UIColor.lightGray.cgColor
            break
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




