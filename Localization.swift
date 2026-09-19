import Foundation

enum ShinnLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "shinn.language"

    case vietnamese = "vi"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum ShinnText {
    // MARK: - Chung
    static func ok(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đồng ý" : "OK"
    }
    static func cancel(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Huỷ" : "Cancel"
    }
    static func done(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Xong" : "Done"
    }
    static func close(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đóng" : "Close"
    }
    static func back(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Quay lại" : "Back"
    }
    static func next(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Tiếp tục" : "Next"
    }
    static func finish(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Hoàn tất" : "Finish"
    }
    static func copy(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Sao chép" : "Copy"
    }
    static func copied(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đã sao chép" : "Copied"
    }
    static func delete(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Xoá" : "Delete"
    }

    // MARK: - Đăng nhập
    static func loginTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đăng nhập" : "Sign In"
    }
    static func loginSubtitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Nhập key truy cập để tiếp tục"
            : "Enter your access key to continue"
    }
    static func keyPlaceholder(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Nhập key" : "Enter key"
    }
    static func usernamePlaceholder(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Tên đăng nhập" : "Username"
    }
    static func signInButton(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "ĐĂNG NHẬP" : "SIGN IN"
    }
    static func keyWrongTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đăng nhập thất bại" : "Sign-In Failed"
    }
    static func keyWrongMessage(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Key hoặc tên đăng nhập không đúng.\nỨng dụng sẽ thoát."
            : "Incorrect key or username.\nThe app will exit."
    }
    static func logout(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đăng xuất" : "Sign Out"
    }

    // MARK: - Role
    static func roleName(_ role: ShinnRole, lang: ShinnLanguage) -> String {
        switch role {
        case .owner: return lang == .vietnamese ? "Chủ sở hữu" : "Owner"
        case .admin: return "Admin"
        case .support: return "Support"
        case .member: return lang == .vietnamese ? "Thành viên" : "Member"
        case .dog: return "Dog"
        }
    }

    // MARK: - Tab
    static func tabHome(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Trang chủ" : "Home"
    }
    static func tabSources(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Nguồn" : "Sources"
    }
    static func tabInstalled(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đã cài" : "Installed"
    }
    static func tabInfo(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Thông tin" : "Info"
    }
    static func tabSettings(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Cài đặt" : "Settings"
    }

    // MARK: - Onboarding
    static func onboardingLegalTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Điều khoản pháp lý" : "Legal Terms"
    }
    static func onboardingLegalBody(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? """
            • Ứng dụng chỉ dành cho mục đích nghiên cứu cá nhân.
            • Không chịu trách nhiệm về vi phạm điều khoản dịch vụ của bên thứ ba (Garena, Tencent, v.v.).
            • Không bán lại, không phân phối thương mại dưới mọi hình thức.
            • Người dùng tự chịu trách nhiệm pháp lý tại nơi cư trú.
            • Mọi hành vi sử dụng trái phép đều do người dùng tự gánh chịu.
            """
            : """
            • This app is for personal research purposes only.
            • Not responsible for third-party ToS violations (Garena, Tencent, etc.).
            • No resale, no commercial distribution in any form.
            • Users bear full legal responsibility in their jurisdiction.
            • All unauthorized use is at the user's own risk.
            """
    }
    static func onboardingRiskTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Cam kết rủi ro" : "Risk Acknowledgment"
    }
    static func onboardingRiskBody(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? """
            • Chấp nhận mọi rủi ro: ban tài khoản, khoá thiết bị, mất dữ liệu.
            • Không khiếu nại, không hoàn tiền, không kiện tụng dưới mọi hình thức.
            • Tự sao lưu dữ liệu quan trọng trước khi sử dụng.
            • Không sử dụng ứng dụng để gây hại cho người khác.
            • Tự chịu trách nhiệm về mọi hậu quả phát sinh.
            """
            : """
            • Accept all risks: account ban, device lock, data loss.
            • No complaints, no refunds, no lawsuits of any kind.
            • Back up important data before use.
            • Do not use the app to harm others.
            • Bear full responsibility for any consequences.
            """
    }
    static func onboardingResponsibilityTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Xác nhận trách nhiệm" : "Responsibility"
    }
    static func onboardingResponsibilityBody(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? """
            • Tôi đã đọc, hiểu và đồng ý toàn bộ điều khoản trên.
            • Tôi từ 18 tuổi trở lên hoặc có sự đồng ý của phụ huynh/người giám hộ.
            • Tôi tự nguyện sử dụng ứng dụng và chịu mọi trách nhiệm.
            • Nếu không đồng ý, tôi sẽ thoát ứng dụng ngay lập tức.
            """
            : """
            • I have read, understood and agreed to all terms above.
            • I am 18+ or have parental/guardian consent.
            • I voluntarily use the app and take full responsibility.
            • If I do not agree, I will exit the app immediately.
            """
    }
    static func onboardingLanguageTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Chọn ngôn ngữ" : "Choose Language"
    }
    static func onboardingCheckbox(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Tôi đã đọc và đồng ý" : "I have read and agree"
    }
    static func onboardingRefuse(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Từ chối và thoát" : "Refuse and Exit"
    }

    // MARK: - Home
    static func homeCategoryTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "DANH MỤC GÓI" : "PACKAGE CATEGORIES"
    }
    static func homeFreeBadge(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Miễn phí 100%" : "100% Free"
    }
    static func homeRepoLabel(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Nguồn" : "Source"
    }
    static func homePackageCount(_ count: Int, lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "\(count) gói" : "\(count) packages"
    }
    static func homeNoAccess(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Bạn không có quyền truy cập nguồn này"
            : "You don't have access to this source"
    }
    static func homeEmpty(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Chưa có gói nào" : "No packages yet"
    }

    // MARK: - Patch
    static func patchApply(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Áp dụng" : "Apply"
    }
    static func patchRestore(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Khôi phục" : "Restore"
    }
    static func patchDownload(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Tải xuống" : "Download"
    }
    static func patchInstalled(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đã cài" : "Installed"
    }
    static func patchNoPermission(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Vai trò của bạn không được phép áp dụng patch"
            : "Your role is not allowed to apply patches"
    }
    static func patchApplyConfirm(_ name: String, lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Áp dụng patch \"\(name)\"? Hãy đóng ứng dụng đích trước khi tiếp tục."
            : "Apply patch \"\(name)\"? Close the target app first."
    }

    // MARK: - Sources
    static func sourcesTitle(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Nguồn repo" : "Repositories"
    }
    static func sourcesDelete(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Xoá nguồn này" : "Delete this source"
    }
    static func sourcesRefresh(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Làm mới" : "Refresh"
    }
    static func sourcesLocked(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Bị khoá theo vai trò" : "Locked by role"
    }

    // MARK: - Info
    static func infoAppSection(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Ứng dụng" : "App"
    }
    static func infoAccountSection(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Tài khoản" : "Account"
    }
    static func infoSystemSection(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Hệ thống" : "System"
    }
    static func infoContactSection(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Liên hệ" : "Contact"
    }
    static func infoDonateSection(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Ủng hộ" : "Donate"
    }
    static func infoVersion(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Phiên bản" : "Version"
    }
    static func infoRole(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Vai trò" : "Role"
    }
    static func infoLoginDate(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đăng nhập lúc" : "Signed in at"
    }
    static func infoDevice(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Thiết bị" : "Device"
    }
    static func infoIOS(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Phiên bản iOS" : "iOS Version"
    }
    static func infoKernelExploit(_ lang: ShinnLanguage) -> String {
        "Kernel Exploit"
    }
    static func infoSandboxEscape(_ lang: ShinnLanguage) -> String {
        "Sandbox Escape"
    }
    static func infoActive(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Hoạt động" : "Active"
    }
    static func infoInactive(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Không khả dụng" : "Unavailable"
    }
    static func infoBank(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Ngân hàng" : "Bank"
    }
    static func infoAccountNumber(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Số tài khoản" : "Account Number"
    }
    static func infoAccountHolder(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Chủ tài khoản" : "Account Holder"
    }

    // MARK: - Settings
    static func settingsLanguage(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Ngôn ngữ" : "Language"
    }
    static func settingsLogs(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Nhật ký" : "Logs"
    }
    static func settingsLegal(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đọc lại điều khoản" : "Review Terms"
    }
    static func settingsUpdate(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Kiểm tra cập nhật" : "Check for Updates"
    }
    static func settingsLogout(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese ? "Đăng xuất" : "Sign Out"
    }
    static func settingsLogoutConfirm(_ lang: ShinnLanguage) -> String {
        lang == .vietnamese
            ? "Bạn có chắc muốn đăng xuất? Bạn sẽ cần nhập lại key."
            : "Are you sure you want to sign out? You will need to enter your key again."
    }
}