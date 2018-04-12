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
import ImageIO

let avatorHeight = 50
let messageCellTextWidth = (Constants.Size.screenWidth - CGFloat(avatorHeight))/4*3


class MessageTableCell: UITableViewCell {
    
    // MARK: - UI variables
    @objc dynamic private var message: Message
    
    private var avatorImageView: UIImageView?
    
    private var contentLabel: UILabel?
    
    private var messageShapeLayer: CAShapeLayer?
    
    private var messageIndicator: UIActivityIndicatorView?
    
    private var optionBtn: UIButton?
    
    private var messageSize: CGSize
    
    private var isUser: Bool
    
    private var fileViewArray: NSMutableArray?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    // MARK: - UI Iplementation
    init(message: Message){
        self.message = message
        self.messageSize = CGSize.zero
        self.isUser = (message.personId == User.CurrentUser.id) || (message.personEmail?.toString() == User.CurrentUser.email)
        super.init(style: .default, reuseIdentifier: "MessageListTableCell")
        self.messageSize = self.getContentSize(text: (message.text)!)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        self.setUpMessageCellSubViews()
    }
    
    public func updateTableCell(message: Message){
        self.message = message
        self.messageSize = CGSize.zero
        self.isUser = (message.personId == User.CurrentUser.id) || (message.personEmail?.toString() == User.CurrentUser.email)
        self.messageSize = self.getContentSize(text: (message.text)!)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        self.setUpMessageCellSubViews()
    }
    
    private func setUpMessageCellSubViews(){
        if(self.avatorImageView == nil){
            if(!isUser){
                self.avatorImageView = UIImageView(frame: CGRect(x: 5, y: 10, width: avatorHeight, height: avatorHeight))
            }else{
                self.avatorImageView = UIImageView(frame: CGRect(x:Int(self.mirrorPosition(5, CGFloat(avatorHeight))), y: 10, width: avatorHeight, height: avatorHeight))
            }
            self.avatorImageView?.layer.cornerRadius = CGFloat(avatorHeight/2)
            self.avatorImageView?.layer.masksToBounds = true
            self.avatorImageView?.layer.borderColor = UIColor.white.cgColor
            self.avatorImageView?.layer.borderWidth = 2.0
            if(self.message.personId == User.CurrentUser.id || self.message.personEmail?.toString() == User.CurrentUser.email){
                if let url = User.CurrentUser.avatorUrl {
                    self.avatorImageView?.sd_setImage(with: URL(string: url), placeholderImage: User.CurrentUser.placeholder)
                }
                else {
                    self.avatorImageView?.image = User.CurrentUser.placeholder
                }
            }else{
                let personEmail = self.message.personEmail
                let groupModel = User.CurrentUser[self.message.localGroupId!]
                let contact = groupModel?.getMemberWithEmail(email: (personEmail?.toString())!)
                if let url = contact?.avatorUrl {
                    self.avatorImageView?.sd_setImage(with: URL(string: url), placeholderImage: contact?.placeholder)
                }
                else {
                    self.avatorImageView?.image = contact?.placeholder
                }
            }
            self.addSubview(self.avatorImageView!)
        }
        if self.message.files != nil{
            self.setUpFileAndContentView()
        }else{
            if self.message.text != nil{
                self.setUpContentlabel()
            }
        }
    }
    
    @objc private func setUpContentlabel(){
        if(self.contentLabel == nil){
            if(self.messageShapeLayer == nil){
                self.messageShapeLayer = CAShapeLayer()
                self.messageShapeLayer?.path = self.getMessageShapePath()
                if(!isUser){
                    self.messageShapeLayer?.fillColor = Constants.Color.Theme.LightMain.cgColor
                }else{
                    self.messageShapeLayer?.fillColor = Constants.Color.Theme.Main.cgColor
                }
                self.layer.addSublayer(messageShapeLayer!)
            }
            
            if(!isUser){
                self.contentLabel = UILabel(frame: CGRect(x: CGFloat(avatorHeight + 20) , y:CGFloat(avatorHeight/2 - 10), width: messageCellTextWidth, height: messageSize.height+20))
            }else{
                let xPosition = self.mirrorPosition(CGFloat(avatorHeight + 20), messageSize.width)
                self.contentLabel = UILabel(frame: CGRect(x: CGFloat(xPosition) , y:CGFloat(avatorHeight/2 - 10), width: messageCellTextWidth, height: messageSize.height+20))
            }
            
            self.contentLabel?.text = self.message.text
            self.contentLabel?.font = Constants.Font.InputBox.Input
            self.contentLabel?.textColor = UIColor.white
            self.contentLabel?.numberOfLines = 0
            self.addSubview(self.contentLabel!)
            if(self.message.messageState == MessageState.willSend){
                self.sendMessage()
            }else{
                self.updateMessageState()
            }
        }
    }
    
    @objc private func setUpFileView(beginY: CGFloat){
        if(self.fileViewArray == nil){
            self.fileViewArray = NSMutableArray()
            var totalY : CGFloat = 0
            do {
                for index in 0..<(message.files?.count)! {
                    guard let file = self.message.files?[index] else{
                        break
                    }
                    var imageViewWidth : CGFloat = 0
                    var imageViewHeight : CGFloat = 0
                    var fileLabelY: CGFloat = 0
                    var fileLableHeight: CGFloat = 0
                    if file.fileType == FileType.Image{
                        imageViewWidth = Constants.Size.screenWidth/2
                        imageViewHeight = Constants.Size.screenWidth/4*3
                        fileLabelY = imageViewHeight/4*3
                        fileLableHeight = imageViewHeight/4
                    }else{
                        imageViewWidth = Constants.Size.screenWidth/2
                        imageViewHeight = Constants.Size.screenWidth/16*3
                        fileLableHeight = imageViewHeight
                    }
                    let imageView = UIImageView()
                    imageView.layer.masksToBounds = true
                    imageView.contentMode = .scaleAspectFill
                    var x1 = CGFloat(avatorHeight + 15)
                    let y1 = beginY + CGFloat(avatorHeight/2 - 10) + totalY + 10*(CGFloat(index))
                    totalY += imageViewHeight
                    if(isUser){
                        x1 = self.mirrorPosition(x1, imageViewWidth)
                    }
                    imageView.frame = CGRect(x1,y1,imageViewWidth,imageViewHeight)
                    imageView.layer.cornerRadius = 3.0
                    imageView.backgroundColor = UIColor.white
                    self.addSubview(imageView)
                    
                    if file.fileType == FileType.Image{
                        if file.thumb != nil{
                            if let localPath = file.thumb?.localFileUrl{
                                imageView.image = UIImage(contentsOfFile: localPath)
                            }else{
                                SparkSDK?.messages?.downLoadThumbNail(roomId: self.message.roomId!, file: file, completionHandler: { (file: FileObjectModel,state: FileDownLoadState) in
                                    if state == .DownloadSuccess{
                                        imageView.image = UIImage(contentsOfFile: (file.thumb?.localFileUrl!)!)
                                    }
                                })
                            }
                        }
                    }
                    let fileNameLabel = UILabel()
                    fileNameLabel.frame = CGRect(x: 0, y: fileLabelY, width: imageViewWidth, height: fileLableHeight)
                    fileNameLabel.text = self.message.fileNames?[index]
                    fileNameLabel.textAlignment = .center
                    fileNameLabel.numberOfLines = 3
                    imageView.addSubview(fileNameLabel)
                    
                    if file.fileType == FileType.Image{
                        fileNameLabel.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.5)
                        fileNameLabel.textColor = UIColor.white
                        fileNameLabel.font = Constants.Font.InputBox.Input
                    }else{
                        fileNameLabel.backgroundColor = UIColor.lightGray
                        fileNameLabel.textColor = UIColor.black
                        fileNameLabel.font = Constants.Font.NavigationBar.Title
                    }
                }
            }
        }
    }
    
    @objc private func setUpFileAndContentView(){
        if self.message.text?.length == 0{
            messageSize.width = Constants.Size.screenWidth/2
            messageSize.height = -10
            let beginY = CGFloat(avatorHeight/2 - 10) + messageSize.height+10
            self.setUpFileView(beginY: beginY)
            if(self.message.messageState == MessageState.willSend){
                self.sendMessage()
            }else{
                self.updateMessageState()
            }
        }else{
            self.setUpContentlabel()
            let beginY = CGFloat(avatorHeight/2 - 10) + messageSize.height+10
            self.setUpFileView(beginY: beginY)
        }

    }
    
    // MARK: SparkSDK: send message 
    @objc private func sendMessage(){
        if(self.message.messageState == MessageState.willSend || self.message.messageState == MessageState.sendFailed){
            self.message.messageState = MessageState.sending
            if(self.messageIndicator == nil){
                self.messageIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                if(!isUser){
                    self.messageIndicator?.center = CGPoint(x: CGFloat(avatorHeight + 20) + messageSize.width+10+10, y: CGFloat(avatorHeight/2)+10.0)
                }else{
                    let positionX = self.mirrorPosition(CGFloat(avatorHeight + 20) + messageSize.width+10+10, 0)
                    self.messageIndicator?.center = CGPoint(x: positionX, y: CGFloat(avatorHeight/2)+10.0)
                }
                self.messageIndicator?.hidesWhenStopped = true
            }
            self.optionBtn?.removeFromSuperview()
            self.addSubview(self.messageIndicator!)
            self.messageIndicator?.startAnimating()
            
            if(self.message.roomId == nil || self.message.roomId?.length == 0){
                DispatchQueue.global().async {
                    let emailStr = User.CurrentUser.loginType == UserLoginType.User ? (self.message.toPersonEmail?.toString())! : self.message.localGroupId
                    SparkSDK?.messages?.post(email: emailStr!, text: (self.message.text!),completionHandler: { (response: ServiceResponse<MessageModel>) in
                        self.messageIndicator?.stopAnimating()
                        switch response.result {
                        case .success(let value):
                            let roomModel = User.CurrentUser.findLocalRoomWithId(localGroupId: self.message.localGroupId!)
                            roomModel?.roomId = value.roomId!
                            User.CurrentUser.saveLocalRooms()
                            self.message.messageId = value.id
                            self.message.messageState = MessageState.idle
                            break
                        case let .failure(error):
                            print(error)
                            self.message.messageState = MessageState.sendFailed
                            self.updateMessageState()
                            break
                        }
                    })
                }
            }else{
                DispatchQueue.global().async {
                    SparkSDK?.messages?.post(roomId: self.message.roomId!, text: (self.message.text!), mentions: self.message.mentionList, files: self.message.files, completionHandler: { (response: ServiceResponse<MessageModel>) in
                            self.messageIndicator?.stopAnimating()
                            switch response.result {
                            case .success(let value):
                                self.message.messageId = value.id
                                self.message.messageState = MessageState.idle
                                break
                            case let .failure(error):
                                print(error)
                                self.message.messageState = MessageState.sendFailed
                                self.updateMessageState()
                                break
                            }
                    })
                }
            }
        }
    }
    
    private func updateMessageState(){
        if(self.message.messageState == MessageState.sendFailed){
            if(self.optionBtn == nil){
                self.optionBtn = UIButton(type: .custom)
                self.optionBtn?.frame = CGRect(0,0,20,20)
                self.optionBtn?.titleLabel?.font = UIFont.fontAwesome(ofSize: 20)
                self.optionBtn?.setTitle(String.fontAwesomeIcon(name: .exclamation), for: .normal)
                self.optionBtn?.setTitleColor(Constants.Color.Theme.Warning, for: .normal)
                self.optionBtn?.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
            }
            if(!isUser){
                self.optionBtn?.center = CGPoint(x: CGFloat(avatorHeight + 20) + messageSize.width+10+10, y: CGFloat(avatorHeight/2)+10.0)
            }else{
                let positionX = self.mirrorPosition(CGFloat(avatorHeight + 20) + messageSize.width+10+10, 0)
                self.optionBtn?.center = CGPoint(x: positionX, y: CGFloat(avatorHeight/2)+10.0)
            }
            self.addSubview(self.optionBtn!)
        }
    }
    
    // MARK: Get Cell Total Height
    public static func getCellHeight(text: String , imageCount: Int , fileCount: Int) -> CGFloat{
        let totalCount = imageCount + fileCount
        if(totalCount > 0 && text.length != 0){
            let textHeight = text.calculateSringHeight(width: Double(CGFloat(messageCellTextWidth)), font: Constants.Font.InputBox.Input)
            if(textHeight+25 > CGFloat(avatorHeight)){
                return textHeight + 45 + (Constants.Size.screenWidth/4*3)*CGFloat(imageCount) + 10*CGFloat(totalCount) + (Constants.Size.screenWidth/16*3)*CGFloat(fileCount)
            }else{
                return CGFloat(avatorHeight) + 15 + (Constants.Size.screenWidth/4*3)*CGFloat(imageCount) + 10*CGFloat(totalCount) + (Constants.Size.screenWidth/16*3)*CGFloat(fileCount)
            }
        }
        if(totalCount > 0){
            return 15 + (Constants.Size.screenWidth/4*3)*CGFloat(imageCount) + 10*CGFloat(totalCount) + (Constants.Size.screenWidth/16*3)*CGFloat(fileCount)
        }
        let textHeight = text.calculateSringHeight(width: Double(CGFloat(messageCellTextWidth)), font: Constants.Font.InputBox.Input)
        if(textHeight+25 > CGFloat(avatorHeight)){
            return textHeight + 45
        }else{
            return CGFloat(avatorHeight) + 15
        }
    }
    
    
    // MARK: Support Functions
    private func getContentSize(text: String) ->CGSize{
        let textSize = text.calculateSringSize(width: Double(CGFloat(messageCellTextWidth)), font: Constants.Font.InputBox.Input)
        return textSize
    }
    
    private func getMessageShapePath() -> CGPath{
        let cornerRadius : CGFloat = 3.0
        let tempPath = UIBezierPath()
        var x1 = CGFloat(avatorHeight + 15)
        var x2 = (x1 + cornerRadius)
        var x4 = (x1+messageSize.width+10)
        var x3 = (x4 - cornerRadius)
        
        let y1 = CGFloat(avatorHeight/2 - 10)
        let y2 = y1 +  cornerRadius
        let y4 = (y1+messageSize.height+20)
        let y3 = y4 - cornerRadius
        
        var triAngleP : CGPoint
        var triAngleP1 : CGPoint
        var triAngleP2 : CGPoint
        
        if(isUser){
            x1 = self.mirrorPosition(x1, messageSize.width+10)
            x2 = (x1+cornerRadius)
            x4 = (x1+messageSize.width+10)
            x3 = (x4 - cornerRadius)
        }
        
        tempPath.move(to: CGPoint(x1,y2))
        tempPath.addQuadCurve(to: CGPoint(x2,y1), controlPoint: CGPoint(x1,y1))
        tempPath.addLine(to: CGPoint(x3,y1))
        tempPath.addQuadCurve(to: CGPoint(x4,y2), controlPoint: CGPoint(x4,y1))
        if(isUser){
            triAngleP = CGPoint(x: self.mirrorPosition(CGFloat(avatorHeight + 8), 0) , y: CGFloat(avatorHeight/2+10))
            triAngleP1 = CGPoint(x: self.mirrorPosition(CGFloat(avatorHeight + 15), 0) , y: CGFloat(avatorHeight/2-4+10))
            triAngleP2 = CGPoint(x: self.mirrorPosition(CGFloat(avatorHeight + 15), 0), y: CGFloat(avatorHeight/2+4+10))
            tempPath.addLine(to: triAngleP1)
            tempPath.addLine(to: triAngleP)
            tempPath.addLine(to: triAngleP2)
        }
        tempPath.addLine(to: CGPoint(x4,y3))
        tempPath.addQuadCurve(to: CGPoint(x3,y4), controlPoint: CGPoint(x4,y4))
        tempPath.addLine(to: CGPoint(x2,y4))
        tempPath.addQuadCurve(to: CGPoint(x1,y3), controlPoint: CGPoint(x1,y4))
        if(!isUser){
            triAngleP = CGPoint(x: CGFloat(avatorHeight + 8), y: CGFloat(avatorHeight/2+10))
            triAngleP1 = CGPoint(x: CGFloat(avatorHeight + 15), y: CGFloat(avatorHeight/2-4+10))
            triAngleP2 = CGPoint(x: CGFloat(avatorHeight + 15), y: CGFloat(avatorHeight/2+4+10))
            tempPath.addLine(to: triAngleP2)
            tempPath.addLine(to: triAngleP)
            tempPath.addLine(to: triAngleP1)
        }
        tempPath.close()
        return tempPath.cgPath
    }
    
    private func mirrorPosition(_ originPosition: CGFloat,_ size: CGFloat)->CGFloat{
        return Constants.Size.screenWidth - originPosition - size
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    
}
