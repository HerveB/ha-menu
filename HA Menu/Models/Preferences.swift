//
//  Preferences.swift
//  HA Menu
//
//  Created by Andrew Jackson on 04/11/2018.
//  Copyright © 2018 CodeChimp. All rights reserved.
//

import Foundation

struct Preferences {

    var settingsVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "settingsVersion")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "settingsVersion")
        }
    }

    var server: String {
        get {
            var serverUrl = UserDefaults.standard.string(forKey: "server") ?? ""
            // Remove trailing slash
            if (serverUrl.hasSuffix("/")) {
                serverUrl.remove(at: serverUrl.index(before: serverUrl.endIndex))
            }
            return serverUrl
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "server")
        }
    }

    var token: String {
        get {
            return UserDefaults.standard.string(forKey: "token") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "token")
        }
    }

    var launch: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "launch")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launch")
        }
    }

    var groupList: String {
        get {
            var groupList = UserDefaults.standard.string(forKey: "group") ?? ""

            // remove all_* groups that are deprecated, we use domains now
            groupList = groupList.replacingOccurrences(of: "all_lights", with: "")
            groupList = groupList.replacingOccurrences(of: "all_switches", with: "")
            groupList = groupList.replacingOccurrences(of: "all_automations", with: "")

            // replace spaces with commas, remove duplicated commas
            groupList = groupList.replacingOccurrences(of: " ", with: ",")
            groupList = groupList.replacingOccurrences(of: ",,", with: ",")

            // remove leading/trailing commas
            if (groupList.hasPrefix(",")) {
                groupList = String(groupList.dropFirst())
            }
            if (groupList.hasSuffix(",")) {
                groupList = String(groupList.dropLast())
            }

            return (groupList)
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "group")
        }
    }

    var groups: [String] {

        var groupArray = [String]()

        // create array of groups, reverse order
        groupArray = self.groupList.components(separatedBy: ",")
        groupArray.reverse()

        return groupArray
    }

    var domainLights: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_lights")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_lights")
        }
    }

    var domainSwitches: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_switches")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_switches")
        }
    }

    var domainAutomations: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_automations")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_automations")
            UserDefaults.standard.synchronize()
        }
    }

    var domainInputBooleans: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_inputbooleans")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_inputbooleans")
            UserDefaults.standard.synchronize()
        }
    }

    var domainInputSelects: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_inputselects")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_inputselects")
            UserDefaults.standard.synchronize()
        }
    }

    var menuItems: [PrefMenuItem] {
        get {
            var decodedResponse = [PrefMenuItem]()

            // Check if string empty
            var jsonString = UserDefaults.standard.string(forKey: "menu_items") ?? ""

            if !jsonString.isEmpty {
                // Got JSON
                do {
                    let jsonData = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false)
                    decodedResponse = try JSONDecoder().decode([PrefMenuItem].self, from: jsonData!)
                    return decodedResponse
                }
                catch {
                    // Something odd with json, blank it out and default
                    jsonString = ""
                }
            }

            if jsonString.isEmpty {
                // Init Domains
                decodedResponse.append(PrefMenuItem(entityId: "light", itemType: itemTypes.Domain, subMenu: false, enabled: domainLights, friendlyName: "Lights"))

                decodedResponse.append(PrefMenuItem(entityId: "switch", itemType: itemTypes.Domain, subMenu: false, enabled: domainSwitches, friendlyName: "Switches"))

                decodedResponse.append(PrefMenuItem(entityId: "automation", itemType: itemTypes.Domain, subMenu: false, enabled: domainAutomations, friendlyName: "Automations"))

                decodedResponse.append(PrefMenuItem(entityId: "input_boolean", itemType: itemTypes.Domain, subMenu: false, enabled: domainInputBooleans, friendlyName: "Input Booleans"))

                decodedResponse.append(PrefMenuItem(entityId: "input_select", itemType: itemTypes.Domain, subMenu: false, enabled: domainInputSelects, friendlyName: "Input Selects"))

                // Init Groups from old setting
                for group in groups {
                    decodedResponse.append(PrefMenuItem(entityId: group, itemType: itemTypes.Group, subMenu: false, enabled: true, friendlyName: ""))
                }
                
                return decodedResponse
            }

            return decodedResponse
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                let dataString = String(data: data, encoding: .utf8)!
                UserDefaults.standard.set(dataString, forKey: "menu_items")

                settingsVersion = 2
            }
            catch {
                // Error encoding json, don't write new value
            }
        }
    }

    func menuItemsWithFriendlyNames(groups: [HaEntity]) -> [String: PrefMenuItem] {
        var completedItems = [String: PrefMenuItem]()

        var index = 0

        for item in menuItems {

            if item.itemType == itemTypes.Group {
                // Check if still a group
                if let group = getGroup(groups: groups, entityId: "group." + item.entityId) {
                    index+=1

                    let completedItem = PrefMenuItem(entityId: item.entityId, itemType: item.itemType, subMenu: item.subMenu, enabled: item.enabled, friendlyName: group.friendlyName, index: index)

                    completedItems[completedItem.entityId] = completedItem
                }
            }
            else {
                index+=1
                var domainItem = item
                domainItem.index = index
                completedItems[item.entityId] = domainItem
            }
        }

        // Add missing groups
        for group in groups {
            if completedItems[group.entityIdNoPrefix] == nil {
                index+=1
                let completedItem = PrefMenuItem(entityId: group.entityIdNoPrefix, itemType: itemTypes.Group, subMenu: false, enabled: false, friendlyName: group.friendlyName, index: index)

                completedItems[group.entityIdNoPrefix] = completedItem
            }
        }

        return completedItems
    }

    private func getGroup(groups: [HaEntity], entityId: String) -> HaEntity? {
        for g in groups {
            if g.entityId == entityId {
                return g
            }
        }
        return nil
    }

}
