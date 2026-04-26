import SwiftUI
import UIKit

let c = Color(UIColor { tc in
    tc.userInterfaceStyle == .dark ? UIColor.red : UIColor.blue
})
print("Success")
