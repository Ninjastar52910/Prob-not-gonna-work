/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared


extension PhotonActionSheetProtocol {

    //Returns a list of actions which is used to build a menu
    //OpenURL is a closure that can open a given URL in some view controller. It is up to the class using the menu to know how to open it
    func getLibraryActions(vcDelegate: PageOptionsVC) -> [PhotonActionSheetItem] {
        guard let tab = self.tabManager.selectedTab else { return [] }

        let openLibrary = PhotonActionSheetItem(title: Strings.AppMenuLibraryTitleString, iconString: "menu-library") { _, _ in
            let bvc = vcDelegate as? BrowserViewController
            bvc?.showLibrary()
        }

        let openHomePage = PhotonActionSheetItem(title: Strings.AppMenuOpenHomePageTitleString, iconString: "menu-Home") { _, _ in
            if let string = UserDefaults.standard.string(forKey: Constant.homeURLKey()),
                let url = URL(string: string)
            {
                tab.loadRequest(URLRequest(url: url))
            }
        }

        return [openHomePage, openLibrary]
    }

    func getOtherPanelActions(vcDelegate: PageOptionsVC) -> [PhotonActionSheetItem] {
        var items: [PhotonActionSheetItem] = []

        let noImageEnabled = NoImageModeHelper.isActivated(profile.prefs)
        let noImageMode = PhotonActionSheetItem(title: Strings.AppMenuNoImageMode, iconString: "menu-NoImageMode", isEnabled: noImageEnabled, accessory: .Switch, badgeIconNamed: "menuBadge") { action,_ in
            NoImageModeHelper.toggle(isEnabled: action.isEnabled, profile: self.profile, tabManager: self.tabManager)
        }

        items.append(noImageMode)

        let nightModeEnabled = NightModeHelper.isActivated(profile.prefs)
        let nightMode = PhotonActionSheetItem(title: Strings.AppMenuNightMode, iconString: "menu-NightMode", isEnabled: nightModeEnabled, accessory: .Switch) { _, _ in
            NightModeHelper.toggle(self.profile.prefs, tabManager: self.tabManager)
            // If we've enabled night mode and the theme is normal, enable dark theme
            if NightModeHelper.isActivated(self.profile.prefs), ThemeManager.instance.currentName == .normal {
                ThemeManager.instance.current = DarkTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: true)
            }
            // If we've disabled night mode and dark theme was activated by it then disable dark theme
            if !NightModeHelper.isActivated(self.profile.prefs), NightModeHelper.hasEnabledDarkTheme(self.profile.prefs), ThemeManager.instance.currentName == .dark {
                ThemeManager.instance.current = NormalTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: false)
            }
        }
        items.append(nightMode)

        let openSettings = PhotonActionSheetItem(title: Strings.AppMenuSettingsTitleString, iconString: "menu-Settings") { _, _ in
            let settingsTableViewController = AppSettingsTableViewController()
            settingsTableViewController.profile = self.profile
            settingsTableViewController.tabManager = self.tabManager
            settingsTableViewController.settingsDelegate = vcDelegate

            let controller = ThemedNavigationController(rootViewController: settingsTableViewController)
            controller.presentingModalViewControllerDelegate = vcDelegate

            // Wait to present VC in an async dispatch queue to prevent a case where dismissal
            // of this popover on iPad seems to block the presentation of the modal VC.
            DispatchQueue.main.async {
                vcDelegate.present(controller, animated: true, completion: nil)
            }
        }
        items.append(openSettings)

        return items
    }

    func syncMenuButton(showFxA: @escaping (_ params: FxALaunchParams?, _ isSignUpFlow: Bool) -> Void) -> PhotonActionSheetItem? {
        profile.getAccount()?.updateProfile()
        let account = profile.getAccount()

        func title() -> String? {
            guard let status = account?.actionNeeded else { return Strings.FxASignInToSync }
            switch status {
            case .none:
                return account?.fxaProfile?.displayName ?? account?.fxaProfile?.email
            case .needsVerification:
                return Strings.FxAAccountVerifyEmail
            case .needsPassword:
                return Strings.FxAAccountVerifyPassword
            case .needsUpgrade:
                return Strings.FxAAccountUpgradeFirefox
            }
        }

        func imageName() -> String? {
            guard let status = account?.actionNeeded else { return "menu-sync" }
            switch status {
            case .none:
                return "placeholder-avatar"
            case .needsVerification, .needsPassword, .needsUpgrade:
                return "menu-warning"
            }
        }

        let action: ((PhotonActionSheetItem, UITableViewCell) -> Void) = { action,_ in
            let fxaParams = FxALaunchParams(query: ["entrypoint": "browsermenu"])
            showFxA(fxaParams, false)
        }

        guard let title = title(), let iconString = imageName() else { return nil }
        guard let actionNeeded = account?.actionNeeded else {
            let signInOption = PhotonActionSheetItem(title: title, iconString: iconString, handler: action)
            return signInOption
        }

        let iconURL = (actionNeeded == .none) ? account?.fxaProfile?.avatar.url : nil
        let iconType: PhotonActionSheetIconType = (actionNeeded == .none) ? .URL : .Image
        let iconTint = (actionNeeded != .none) ? UIColor.Photon.Yellow60 : nil
        let syncOption = PhotonActionSheetItem(title: title, iconString: iconString, iconURL: iconURL, iconType: iconType, iconTint: iconTint, accessory: .Sync, handler: action)
        return syncOption
    }
}
