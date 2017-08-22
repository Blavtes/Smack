//
//  ChatVC.swift
//  Smack
//
//  Created by Tushar Katyal on 19/08/17.
//  Copyright © 2017 Tushar Katyal. All rights reserved.
//

import UIKit

class ChatVC: UIViewController, UITableViewDelegate,UITableViewDataSource {

    
    //outlets
    @IBOutlet weak var menuBtn: UIButton!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var channelName: UILabel!
    @IBOutlet weak var tableView : UITableView!
    @IBOutlet weak var sendBtn: UIButton!
    var isTyping = false
    
    @IBOutlet weak var typingUserLbl: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sendBtn.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableViewAutomaticDimension
        menuBtn.addTarget(self.revealViewController(), action: #selector(SWRevealViewController.revealToggle(_:)), for: .touchUpInside)
    
        self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        self.view.addGestureRecognizer(self.revealViewController().tapGestureRecognizer())
        view.bindToKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ChatVC.handleTap))
        view.addGestureRecognizer(tap)
        // notifcation observed when user selects the channel
        NotificationCenter.default.addObserver(self, selector: #selector(ChatVC.channelSelected(_:)), name: NOTIF_CHANNEL_SELECTED, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatVC.userDataDidChange(_:)), name: NOTIF_USER_DATA_DID_CHANGE, object: nil)
        
        SocketService.instance.getChatMessage { (success) in
            if success {
                self.tableView.reloadData()
             
              if MessageService.instance.messages.count > 0 {
                       let endIndex = IndexPath(row: MessageService.instance.messages.count - 1, section: 0)
                    self.tableView.scrollToRow(at: endIndex, at: .bottom , animated: false)
                    }
                }
            }
        
        SocketService.instance.getTypingUsers { (typingUsers) in
            guard let channelId = MessageService.instance.selectedChannel?.channelId else{return}
            var names = ""
            var noOfTypers = 0
            for (typingUser,channel) in typingUsers {
                if typingUser != UserDataService.instance.name && channel == channelId {
                    if names == "" {
                        names = typingUser
                    } else{
                        names = "\(names),\(typingUser)"
                    }
                    noOfTypers += 1
                }
            }
            if noOfTypers > 0 && AuthService.instance.isLoggedIn == true {
                var verb = "is"
                if noOfTypers > 1 {
                    verb = "are"
                }
                self.typingUserLbl.text = "\(names) \(verb) typing a message ..."
            } else {
                self.typingUserLbl.text = ""
            }
        }
        
        if AuthService.instance.isLoggedIn {
            AuthService.instance.findUserByEmail(completion: { (success) in
               
                if success {
                NotificationCenter.default.post(name: NOTIF_USER_DATA_DID_CHANGE, object: nil)
            }
            })
        }
    }
    @objc func handleTap() {
        view.endEditing(true)
    }
    @objc func channelSelected(_ notif : Notification){
        
        updateWithChannel()
    }
    // message table view update
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "messageCell", for: indexPath) as? MessageCell {
            
            let message = MessageService.instance.messages[indexPath.row]
            cell.configureCell(message: message)
            return cell
        }
        return UITableViewCell()
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MessageService.instance.messages.count
    }
    
    func updateWithChannel(){
        
        let channelTitle = MessageService.instance.selectedChannel?.channelName ?? ""
        channelName.text = "#\(channelTitle)"
        getMessages()
    }
    
    @objc func userDataDidChange(_ notif : Notification) {
       
        if AuthService.instance.isLoggedIn {
            onLoginGetMessages()
        } else {
            channelName.text = "Please Log in"
            tableView.reloadData()
        }
    }
    
    func onLoginGetMessages(){
        MessageService.instance.findAllChannels(completion: { (success) in
            
            if success {
              if  MessageService.instance.channels.count > 0 {
                MessageService.instance.selectedChannel = MessageService.instance.channels[0]
                self.updateWithChannel()
              } else {
                
                self.channelName.text = "No channels Yet!"
                }
            }
        })
    }

    func getMessages(){
        guard let channelId = MessageService.instance.selectedChannel?.channelId else {return}
        
        MessageService.instance.findAllMessageForChannel(channelId: channelId) { (success) in
            if success {
                self.tableView.reloadData()
            }
            
        }
        
    }
    // To send message
    @IBAction func sendMessagePressed(_ sender: Any) {
        
        if AuthService.instance.isLoggedIn {
            guard let channelId = MessageService.instance.selectedChannel?.channelId else {return}
            guard let message = messageField.text , messageField.text != "" else {
                self.messageField.resignFirstResponder() 
                return}
            
            SocketService.instance.addMessage(messageBody: message, userId: UserDataService.instance.id, channelId: channelId, completion: { (success) in
                
                if success {
                    self.messageField.text = ""
                    self.messageField.resignFirstResponder()
                    SocketService.instance.socket.emit("stopType", UserDataService.instance.name ,channelId)
                }
            })
        }
    }
  
    @IBAction func editing(_ sender: Any) {
        guard let channelId = MessageService.instance.selectedChannel?.channelId else {return}
        if messageField.text == "" {
            isTyping = false
            sendBtn.isHidden = true
            SocketService.instance.socket.emit("stopType", UserDataService.instance.name,channelId)
        } else {
           if isTyping == false {
                sendBtn.isHidden = false
                SocketService.instance.socket.emit("startType", UserDataService.instance.name,channelId)
            }
            isTyping = true
        }
    }
    
}
