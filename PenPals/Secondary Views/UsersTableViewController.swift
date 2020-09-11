//
//  UsersTableViewController.swift
//  PenPals
//
//  Created by Tim Van Cauwenberge on 3/24/20.
//  Copyright © 2020 SeniorProject. All rights reserved.
//

import UIKit
import Firebase
import JGProgressHUD

class UsersTableViewController: UITableViewController, UISearchResultsUpdating, ContactsTableViewCellDelegate {
    
    
    var allUsers: [FUser] = []
    var filteredUsers: [FUser] = []
    var allUsersGrouped = NSDictionary() as! [String : [FUser]]
    var sectionTitleList : [String] = []
    
    var hud = JGProgressHUD(style: .dark)
    
    let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Your Friends", comment: "")
        navigationItem.largeTitleDisplayMode = .never
        tableView.tableFooterView = UIView()
        
        navigationItem.searchController = searchController
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
        
        self.loadTheFriendUsers()
        //loadUsers()
        
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        //dynamically checks if user is searching for users
        if searchController.isActive && searchController.searchBar.text != "" {
            return 1
        } else {
            return allUsersGrouped.count
        }
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive && searchController.searchBar.text != "" {
            
            return filteredUsers.count
        } else {
            //find section title
            let sectionTitle = self.sectionTitleList[section]
            
            // user for given title
            let users = self.allUsersGrouped[sectionTitle]
            
            return users!.count
        }
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ContactsTableViewCell
        
        
        var user: FUser
        
        // if we have a search
        if searchController.isActive && searchController.searchBar.text != "" {
            
            user = filteredUsers[indexPath.row]
            
        } else {
            
            let sectionTitle = self.sectionTitleList[indexPath.section]
            
            let users = self.allUsersGrouped[sectionTitle]
            
            user = users![indexPath.row]
        }
        
        cell.generateCellWith(fUser: user, indexPath: indexPath)
        
        cell.delegate = self
        
        return cell
    }
    
    //MARK: TableView delegate
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return ""
        } else {
            return sectionTitleList[section]
        }
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return nil
        } else {
            return self.sectionTitleList
        }
        
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        
        return index
    }
    
    // fixes cell height bug
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        var user: FUser
        
        // if we have a search
        if searchController.isActive && searchController.searchBar.text != "" {
            
            user = filteredUsers[indexPath.row]
            
        } else {
            
            let sectionTitle = self.sectionTitleList[indexPath.section]
            
            let users = self.allUsersGrouped[sectionTitle]
            
            user = users![indexPath.row]
        }
        
        // starts 1v1 chat
        
        if !checkBlockedStatus(withUser: user) {
            let messageVC = MessageViewController()
            messageVC.titleName = user.firstname
            messageVC.membersToPush = [FUser.currentId(), user.objectId]
            messageVC.memberIds = [FUser.currentId(), user.objectId]
            
            messageVC.chatRoomId = startPrivateChat(user1: FUser.currentUser()!, user2: user)
            messageVC.isGroup = false
            messageVC.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(messageVC, animated: true)
            
        } else {
            self.hud.textLabel.text = "This user is not available for chatting!"
            self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
            self.hud.show(in: self.view)
            self.hud.dismiss(afterDelay: 1.5, animated: true)
            
        }
    }
    
    func loadTheFriendUsers() {
        if FUser.currentUser()!.friendListIds.count > 0 {
            
            hud.show(in: self.view)
            
            getUsersFromFirestore(withIds:  FUser.currentUser()!.friendListIds) { (allFriendUsers) in
                
                self.hud.dismiss()
                
                self.allUsers = allFriendUsers
                
                self.splitDataIntoSections()
                self.tableView.reloadData()
                
            }
            self.tableView.reloadData()
        }
        self.tableView.reloadData()
        
    }
    
    func loadUsers() {
        
        // show loading bar
        hud.show(in: self.view)

        var query: Query!
        query = reference(.User).order(by: kFIRSTNAME, descending: false)

        
        // snapshot = each users data
        query.getDocuments { (snapshot, error) in
            
            self.allUsers = []
            //            self.sectionTitleList = []
            self.allUsersGrouped = [:]
            
            if error != nil {
                print(error!.localizedDescription)
                
                self.hud.textLabel.text = "\(error!.localizedDescription)"
                self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                self.hud.show(in: self.view)
                self.hud.dismiss(afterDelay: 1.5, animated: true)
                
                self.tableView.reloadData()
                return
            }
            
            guard let snapshot = snapshot else {
                self.hud.dismiss()
                return
            }
            
            // if we have data then present it
            if !snapshot.isEmpty {
                
                for userDictionary in snapshot.documents {
                    
                    let userDictionary = userDictionary.data() as NSDictionary
                    
                    // create an instance of the user's contacts in an array
                    let fUser = FUser(_dictionary: userDictionary)
                    
                    // check to make sure the current user in the contacts
                    // is not the same as the current user logged in
                    if fUser.objectId != FUser.currentId() {
                        
                        //add all the users gathered into the allUsers array
                        self.allUsers.append(fUser)
                    }
                }
                
                //split to groups
                self.splitDataIntoSections()
                self.tableView.reloadData()
            }
            
            //refresh tableView
            self.tableView.reloadData()
            self.hud.dismiss()
        }
        
        
    }
    
    
    //MARK: Search controller functions
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        
        filteredUsers = allUsers.filter({ (user) -> Bool in
            
            return user.firstname.lowercased().contains(searchText.lowercased())
        })
        
        tableView.reloadData()
        
    }
    
    
    func updateSearchResults(for searchController: UISearchController) {
        
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
    
    
    //MARK: Helper Functions
    
    fileprivate func splitDataIntoSections() {
        
        var sectionTitle: String = ""
        
        //loop through all users
        for i in 0..<self.allUsers.count {
            
            let currentUser = self.allUsers[i]
            
            //get first character of user's name
            let firstChar = currentUser.firstname.first!
            
            let firstCharString = "\(firstChar)"
            
            if firstCharString != sectionTitle {
                
                sectionTitle = firstCharString
                
                self.allUsersGrouped[sectionTitle] = []
                
                self.sectionTitleList.append(sectionTitle)
            }
            
            self.allUsersGrouped[firstCharString]?.append(currentUser)
        }
    }
    
    //MARK: UserTableViewCellDelegate
    
    func didTapAvatarImage(indexPath: IndexPath) {
        print("User avatar tap at \(indexPath)")
        
        let profileVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(identifier: "profileView") as! ProfileViewTableViewController
        
        var user: FUser
        
        // if we have a search
        if searchController.isActive && searchController.searchBar.text != "" {
            
            // users the current user is searching for
            user = filteredUsers[indexPath.row]
            
        } else {
            
            //otherwise just show all the users
            let sectionTitle = self.sectionTitleList[indexPath.section]
            
            let users = self.allUsersGrouped[sectionTitle]
            
            user = users![indexPath.row]
        }
        
        profileVC.user = user
        self.navigationController?.pushViewController(profileVC, animated: true)
    }
    
}

