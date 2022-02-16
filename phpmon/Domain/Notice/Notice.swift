//
//  Notice.swift
//  PHP Monitor
//
//  Created by Nico Verbruggen on 16/02/2022.
//  Copyright © 2022 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa

class Notice {
    
    var windowController: NSWindowController!
    
    var noticeVC: NoticeVC {
        return self.windowController.contentViewController as! NoticeVC
    }
    
    public static func make() -> Notice {
        let storyboard = NSStoryboard(name: "Main" , bundle : nil)
        
        let notice = Notice()
        notice.windowController = storyboard.instantiateController(
            withIdentifier: "noticeWindow"
        ) as? NSWindowController
        return notice
    }
    
    public func withPrimary(
        text: String,
        action: @escaping (NoticeVC) -> Void = {
            vc in vc.close(with: .alertFirstButtonReturn)
        }
    ) -> Self {
        self.noticeVC.buttonPrimary.title = text
        self.noticeVC.actionPrimary = action
        return self
    }
    
    public func withSecondary(
        text: String,
        action: ((NoticeVC) -> Void)? = nil
    ) -> Self {
        self.noticeVC.buttonSecondary.title = text
        self.noticeVC.actionSecondary = action
        return self
    }
    
    public func withTertiary(
        text: String,
        action: ((NoticeVC) -> Void)? = nil
    ) -> Self {
        self.noticeVC.buttonTertiary.title = text
        self.noticeVC.actionTertiary = action
        return self
    }
    
    public func withInformation(
        title: String,
        subtitle: String,
        description: String = ""
    ) -> Self {
        self.noticeVC.labelTitle.stringValue = title
        self.noticeVC.labelSubtitle.stringValue = subtitle
        self.noticeVC.labelDescription.stringValue = description
        
        // If the description is missing, handle the excess space and change the top margin
        if (description == "") {
            self.noticeVC.labelDescription.isHidden = true
            self.noticeVC.primaryButtonTopMargin.constant = 0
        }
        return self
    }
    
    public func present() -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        windowController.window?.makeKeyAndOrderFront(nil)
        return NSApplication.shared.runModal(for: windowController.window!)
    }
}
