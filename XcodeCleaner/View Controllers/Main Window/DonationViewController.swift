//
//  DonationViewController.swift
//  XcodeCleaner
//
//  Created by Konrad Kołakowski on 19.05.2018.
//  Copyright © 2018 One Minute Games. All rights reserved.
//
//  XcodeCleaner is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  XcodeCleaner is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with XcodeCleaner.  If not, see <http://www.gnu.org/licenses/>.

import Cocoa
import StoreKit

internal final class DonationViewController: NSViewController {
    // MARK: Properties & outlets
    @IBOutlet weak var xcodeCleanerBenefitsTextField: NSTextField!
    @IBOutlet weak var closeButton: NSButton!
    
    @IBOutlet weak var lunchPriceLabel: NSTextField!
    @IBOutlet weak var lunchInfoLabel: NSTextField!
    
    @IBOutlet weak var bigCoffeePriceLabel: NSTextField!
    @IBOutlet weak var bigCoffeeInfoLabel: NSTextField!
    
    @IBOutlet weak var smallCoffeePriceLabel: NSTextField!
    @IBOutlet weak var smallCoffeeInfoLabel: NSTextField!
    
    private var loadingView: LoadingView! = nil
    
    private var productsRequest: SKProductsRequest? = nil
    private var iapProducts: [SKProduct] = []
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // update benefits label
        self.xcodeCleanerBenefitsTextField.attributedStringValue = self.benefitsAttributedString(totalBytesCleaned: Preferences.shared.totalBytesCleaned)
        
        // update donation products
        self.fetchProductsInfo()
        
        // start loading
        self.loadingView = LoadingView(frame: self.view.frame)
        self.view.addSubview(self.loadingView, positioned: .below, relativeTo: self.closeButton)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // MARK: Helpers
    private func benefitsAttributedString(totalBytesCleaned: Int64) -> NSAttributedString {
        let totalBytesString = ByteCountFormatter.string(fromByteCount: totalBytesCleaned, countStyle: .file)
        
        let fontSize: CGFloat = 13.0
        let result = NSMutableAttributedString()
        
        let partOne = NSAttributedString(string: "You saved total of ",
                                           attributes: [.font : NSFont.systemFont(ofSize: fontSize)])
        result.append(partOne)
        
        let partTwo = NSAttributedString(string: "\(totalBytesString)",
                                            attributes: [.font : NSFont.boldSystemFont(ofSize: fontSize)])
        result.append(partTwo)
        
        let partThree = NSAttributedString(string: " thanks to XcodeCleaner!",
                                           attributes: [.font : NSFont.systemFont(ofSize: fontSize)])
        result.append(partThree)
        
        return result
    }
    
    // MARK: Purchasing donations
    private func fetchProductsInfo() {
        let donationProductsIds = ["SMALL_COFFEE", "BIG_COFFEE", "LUNCH"]
        
        self.productsRequest = SKProductsRequest(productIdentifiers: Set(donationProductsIds))
        self.productsRequest?.delegate = self
        self.productsRequest?.start()
    }
    
    private func buy(product: SKProduct) {
        
    }
}

extension DonationViewController: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.loadingView.removeFromSuperview()
        }
        
        self.iapProducts = response.products
        for product in self.iapProducts {
            log.info("SupportViewController: Product received: \(product.productIdentifier) = \(product.localizedTitle)")
            
            DispatchQueue.main.async {
                let nf = NumberFormatter()
                nf.numberStyle = .currency
                nf.locale = product.priceLocale
                
                switch product.productIdentifier {
                    case "SMALL_COFFEE":
                        self.smallCoffeePriceLabel.stringValue = nf.string(from: product.price) ?? ""
                        self.smallCoffeeInfoLabel.stringValue = product.localizedTitle
                    case "BIG_COFFEE":
                        self.bigCoffeePriceLabel.stringValue = nf.string(from: product.price) ?? ""
                        self.bigCoffeeInfoLabel.stringValue = product.localizedTitle
                    case "LUNCH":
                        self.lunchPriceLabel.stringValue = nf.string(from: product.price) ?? ""
                        self.lunchInfoLabel.stringValue = product.localizedTitle
                    default:
                        log.error("SupportViewController: Unrecognized product: \(product.productIdentifier)")
                }
            }
        }
    }
}

