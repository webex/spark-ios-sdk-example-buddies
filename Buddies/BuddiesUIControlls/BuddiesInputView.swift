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

class BuddiesInputView: UIView {
    
    public var sendBtnClickBlock : ((_ text : String)->())?
    
    private static var myContext = 0
    private var tableView: UITableView
    public var inputTextView: UITextView?
    private var sendBtn: UIButton?
    private var tableTap: UIGestureRecognizer?
    private var plusBtn: UIButton?
    private let textViewX = 50
    private let textViewY = 2
    private let textViewWidth = Int((Constants.Size.screenWidth - 140))
    private let textViewHeight = 36
    
    
    
    
    init(frame: CGRect , tableView: UITableView){
        self.tableView = tableView
        super.init(frame: frame)
        self.setUpSubViews()
        NotificationCenter.default.addObserver(self, selector: #selector(keyBoardWillAppear(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyBoardWillDisappear(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc private func plusBtnClicked(){

        let inputViewHeight = Constants.Size.screenWidth > 375 ? 226 : 216
        let imageInputView = UIView(frame: CGRect(0,0,Int(Constants.Size.screenWidth),inputViewHeight))
            imageInputView.backgroundColor = UIColor.gray
        let instructLabel = UILabel(frame:  CGRect(0,0,Int(Constants.Size.screenWidth),inputViewHeight))
        instructLabel.text = "In Developing..."
        instructLabel.textAlignment = .center
        instructLabel.textColor = UIColor.white
        instructLabel.font = Constants.Font.NavigationBar.Title
        imageInputView.addSubview(instructLabel)
        
        self.inputTextView?.inputView = imageInputView
        self.inputTextView?.reloadInputViews()
//        var control = UIControl(frame: self.inputTextView?.frame)
        let control = UIControl(frame: (self.inputTextView?.bounds)!)
        control.addTarget(self, action: #selector(textViewClicked), for: .touchUpInside)
        self.inputTextView?.addSubview(control)
//        UIControl *control = [[UIControl alloc] initWithFrame:_inputView.bounds];
//        [control addTarget:self action:@selector(inputViewTapHandle) forControlEvents:UIControlEventTouchUpInside];
//        [_inputView addSubview:control];
//        self.inputTextView?.becomeFirstResponder()
    }
    
    @objc private func textViewClicked(){
        self.inputTextView?.inputView = nil
        self.inputTextView?.becomeFirstResponder()
        self.inputTextView?.reloadInputViews()
    }
    
    // MARK: - UI Implementation
    func setUpSubViews(){
        let bottomViewWidth = Constants.Size.screenWidth
        self.backgroundColor = UIColor.white
        
        self.plusBtn = UIButton(frame: CGRect(x: 14, y: 7, width: 26, height: 26))
        
        self.plusBtn?.setImage(UIImage(named: "icon_plus"), for: .normal)
        self.plusBtn?.addTarget(self, action: #selector(plusBtnClicked), for: .touchUpInside)
        self.addSubview(self.plusBtn!)
        
        self.inputTextView = UITextView(frame: CGRect(x: textViewX, y: textViewY, width: textViewWidth, height: textViewHeight))
        self.inputTextView?.textAlignment = .center
        self.inputTextView?.tintColor = Constants.Color.Theme.Main
        self.inputTextView?.layer.borderColor = UIColor.clear.cgColor
        self.inputTextView?.font = Constants.Font.InputBox.Input
        self.inputTextView?.textAlignment = .left
        self.inputTextView?.returnKeyType = .default;
        self.inputTextView?.layer.cornerRadius = 5.0
        self.inputTextView?.layer.borderColor = Constants.Color.Theme.Main.cgColor
        self.inputTextView?.layer.borderWidth = 1.0
        self.inputTextView?.layoutManager.allowsNonContiguousLayout = false
        self.inputTextView?.addObserver(self, forKeyPath:"contentSize" , options: [NSKeyValueObservingOptions.old , NSKeyValueObservingOptions.new], context: &BuddiesInputView.myContext)
        self.addSubview(self.inputTextView!)
        
        self.sendBtn = UIButton(frame: CGRect(x: bottomViewWidth-80, y: 5, width: 70, height: 30))
        self.sendBtn?.setTitle("Send", for: .normal)
        self.sendBtn?.backgroundColor = Constants.Color.Theme.Main
        self.sendBtn?.titleLabel?.font = Constants.Font.InputBox.Input
        self.sendBtn?.layer.cornerRadius = 15
        self.sendBtn?.layer.masksToBounds = true
        self.sendBtn?.addTarget(self, action: #selector(sendBtnClicked), for: .touchUpInside)
        self.addSubview(self.sendBtn!)
    }
    
    
    // MARK: UI Logic Implementation
    func keyBoardWillAppear(notification: Notification){
        if(tableTap == nil){
            tableTap =  UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        }
        self.tableView.addGestureRecognizer(tableTap!)
        let userInfo = notification.userInfo!
        let keyboardFrame:NSValue = userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        let currentTableInsetBottom = self.tableView.contentInset.bottom
        UIView.animate(withDuration: 0.25) {
            self.tableView.transform = CGAffineTransform.init(translationX: 0, y: -keyboardHeight)
            self.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight)
            self.tableView.contentInset = UIEdgeInsetsMake(keyboardHeight, 0, currentTableInsetBottom, 0)
        }
    }
    
    func keyBoardWillDisappear(notification: Notification){
        if(tableTap != nil){
            self.tableView.removeGestureRecognizer(tableTap!)
        }
        let currentTableInsetBottom = self.tableView.contentInset.bottom
        UIView.animate(withDuration: 0.25) {
            self.tableView.transform = CGAffineTransform.init(translationX: 0, y: 0)
            self.transform = CGAffineTransform(translationX: 0, y: 0)
            self.tableView.contentInset = UIEdgeInsetsMake(0, 0, currentTableInsetBottom, 0)
        }
    }
    
    // MARK: - UITextView/Delegate Observer Implemenation
    @objc override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &BuddiesInputView.myContext{
            if let newValue = change?[.newKey] as? CGSize, let oldValue = change?[.oldKey] as? CGSize, newValue != oldValue {
                var contentHeight = newValue.height
                let textViewWidth = self.textViewWidth
                if(contentHeight < 36){
                    contentHeight = 36
                }else if(contentHeight >= 120){
                    contentHeight = 120
                }
                let gap = contentHeight - self.frame.size.height + 4
                if(newValue.height >= oldValue.height){
                    self.inputTextView?.frame = CGRect(x: textViewX, y: textViewY, width: textViewWidth, height: Int(contentHeight))
                    self.frame.size.height = contentHeight+4
                    UIView.animate(withDuration: 0.15, animations: {
                        self.updateTableViewInset(-gap)
                    })
                }else{
                    self.inputTextView?.frame = CGRect(x: textViewX, y: textViewY, width: textViewWidth, height: Int(contentHeight))
                    UIView.animate(withDuration: 0.15, animations: {
                        self.frame.size.height = contentHeight+4
                        self.updateTableViewInset(-gap)
                    })
                    
                }
            }
        }
    }
    
    
    func updateTableViewInset(_ height: CGFloat){
        let currentTableInsetBottom = self.tableView.contentInset.bottom
        let currentTableInsetTop = self.tableView.contentInset.top
        self.tableView.contentInset = UIEdgeInsetsMake(currentTableInsetTop, 0, currentTableInsetBottom-height, 0)
        let contentHeight = self.tableView.contentSize.height
        let contentOffSetY = self.tableView.contentOffset.y
        let delta = contentHeight - contentOffSetY
        let animate = delta > Constants.Size.screenHeight ? true : false
        self.tableView.setContentOffset(CGPoint(0,contentOffSetY-height), animated: animate)
        self.frame.origin.y += (height)
        self.sendBtn?.frame.origin.y -= (height)
        self.plusBtn?.frame.origin.y -= (height)
    }
    
    @objc private func tableViewTapped(){
        self.inputTextView?.resignFirstResponder()
    }
    
    
    deinit{
        self.inputTextView?.removeObserver(self, forKeyPath: "contentSize")
    }
    
    // MARK: InputView Delegate Part
    @objc private func sendBtnClicked(){
        if(self.inputTextView?.text.length == 0){
            return
        }
        if(self.sendBtnClickBlock != nil){
            self.sendBtnClickBlock!((self.inputTextView?.text)!)
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
